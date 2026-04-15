local VFS = {}
VFS.__index = VFS

local Prefix = "[VFS]:"
local Types  = require("/KRNL/kernel/Utils/Types")
local Codec  = require("/KRNL/kernel/Utils/Codec")

type NodeType = Types.NodeType
type Node     = Types.Node

-- ════════════════════════════════════
--  Private Helpers
-- ════════════════════════════════════

local function splitPath(path: string): { string }
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    return parts
end

local function makeFile(name: string, content: string): Node
    return {
        name     = name,
        type     = "file",
        content  = content,
        children = nil,
        size     = #content,
        modified = 0,
    }
end

local function makeDir(name: string): Node
    return {
        name     = name,
        type     = "directory",
        content  = nil,
        children = {},
        size     = 0,
        modified = 0,
    }
end

-- ════════════════════════════════════
--  Constructor
-- ════════════════════════════════════

function VFS.new(flash_driver,name,registry)
    local self    = setmetatable({}, VFS)
    self.driver   = flash_driver
    self.mounted  = false
    self.root     = makeDir("root")
		registry[name] = self
		
    return self
end

-- ════════════════════════════════════
--  Traverse
-- ════════════════════════════════════

-- Возвращает (node, parent, name)
-- node   = найденный узел или nil
-- parent = родительская директория или nil
-- name   = имя последнего сегмента пути
function VFS:_traverse(path: string): (Node?, Node?, string?)
    local parts   = splitPath(path)
    local current = self.root
    local parent  = nil

    if #parts == 0 then
        return self.root, nil, nil
    end

    for i, part in ipairs(parts) do
        if current.type ~= "directory" or not current.children then
            return nil, nil, nil
        end

        parent = current
        local next = current.children[part]

        if not next then
            if i == #parts then
                return nil, parent, part
            else
                return nil, nil, nil
            end
        end

        current = next

        if i == #parts then
            return current, parent, part
        end
    end

    return nil, nil, nil
end

-- ════════════════════════════════════
--  Mount / Commit
-- ════════════════════════════════════

function VFS:Mount(): boolean
    if self.mounted then
        logWarning(string.format("%s Already mounted", Prefix))
        return false
    end

    local data = self.driver:Load()

    if data and data.root then
        self.root   = data.root
        self.mounted = true
        log(string.format("%s Mounted from FlashMemory", Prefix))
    else
        self.root    = makeDir("root")
        self.mounted = true
        self:_createDefaultStructure()
        self:Commit()
        log(string.format("%s Fresh mount, default structure created", Prefix))
    end

    return true
end

function VFS:_createDefaultStructure()
    self.root.children["bin"]  = makeDir("bin")
    self.root.children["system"]  = makeDir("etc")
    self.root.children["home"] = makeDir("home")
    self.root.children["tmp"]  = makeDir("tmp")
    self.root.children["system"].children["config.cfg"] = makeFile("config.cfg", Codec.Serialize({
        theme   = "default",
        version = "0.1.0",
    }))
end

function VFS:Commit(): boolean
    if not self.mounted then
        logWarning(string.format("%s Cannot commit not mounted", Prefix))
        return false
    end

    local ok = self.driver:Save({ root = self.root })
    if ok then
        log(string.format("%s Committed to FlashMemory", Prefix))
    else
        logWarning(string.format("%s Commit failed not enough space", Prefix))
    end
    return ok
end

-- ════════════════════════════════════
--  File API
-- ════════════════════════════════════

function VFS:Write(path: string, content: string): boolean
    if not self.mounted then return false end

    local node, parent, name = self:_traverse(path)

    if node then
        if node.type == "directory" then
            logWarning(string.format("%s Write failed: '%s' is a directory", Prefix, path))
            return false
        end
        node.content  = content
        node.size     = #content
        node.modified = 0
    elseif parent and name then
        parent.children[name] = makeFile(name, content)
    else
        logWarning(string.format("%s Write failed: invalid path '%s'", Prefix, path))
        return false
    end

    self:Commit()
    return true
end

function VFS:Read(path: string): string?
    if not self.mounted then return nil end

    local node = self:_traverse(path)
    if not node then
        logWarning(string.format("%s Read failed: '%s' not found", Prefix, path))
        return nil
    end
    if node.type ~= "file" then
        logWarning(string.format("%s Read failed: '%s' is a directory", Prefix, path))
        return nil
    end

    return node.content
end

function VFS:WriteTable(path: string, data: {any}): boolean
    local serialized = Codec.Serialize(data)
    return self:Write(path, serialized)
end

function VFS:ReadTable(path: string): {any}?
    local content = self:Read(path)
    if not content then return nil end
    return Codec.Deserialize(content)
end

function VFS:MakeDir(path: string): boolean
    if not self.mounted then return false end

    local node, parent, name = self:_traverse(path)

    if node then
        logWarning(string.format("%s MakeDir failed: '%s' already exists", Prefix, path))
        return false
    end
    if not parent or not name then
        logWarning(string.format("%s MakeDir failed: invalid path '%s'", Prefix, path))
        return false
    end

    parent.children[name] = makeDir(name)
    self:Commit()
    return true
end

function VFS:List(path: string): { string }?
    if not self.mounted then return nil end

    local node = self:_traverse(path)
    if not node then
        logWarning(string.format("%s List failed: '%s' not found", Prefix, path))
        return nil
    end
    if node.type ~= "directory" then
        logWarning(string.format("%s List failed: '%s' is not a directory", Prefix, path))
        return nil
    end

    local result = {}
    for name, child in pairs(node.children) do
        local suffix = child.type == "directory" and "/" or ""
        table.insert(result, name .. suffix)
    end
    table.sort(result)
    return result
end

function VFS:Remove(path: string): boolean
    if not self.mounted then return false end

    local node, parent, name = self:_traverse(path)
    if not node or not parent or not name then
        logWarning(string.format("%s Remove failed: '%s' not found", Prefix, path))
        return false
    end

    if node.type == "directory" and next(node.children) ~= nil then
        logWarning(string.format("%s Remove failed: directory '%s' is not empty", Prefix, path))
        return false
    end

    parent.children[name] = nil
    self:Commit()
    return true
end

function VFS:RemoveAll(path: string): boolean
    if not self.mounted then return false end

    local node, parent, name = self:_traverse(path)
    if not node or not parent or not name then
        logWarning(string.format("%s RemoveAll failed: '%s' not found", Prefix, path))
        return false
    end

    parent.children[name] = nil
    self:Commit()
    return true
end

function VFS:Exists(path: string): boolean
    if not self.mounted then return false end
    return self:_traverse(path) ~= nil
end

function VFS:IsFile(path: string): boolean
    if not self.mounted then return false end
    local node = self:_traverse(path)
    return node ~= nil and node.type == "file"
end

function VFS:IsDir(path: string): boolean
    if not self.mounted then return false end
    local node = self:_traverse(path)
    return node ~= nil and node.type == "directory"
end

function VFS:Stat(path: string): Node?
    if not self.mounted then return nil end
    return self:_traverse(path)
end

function VFS:Copy(src: string, dst: string): boolean
    if not self.mounted then return false end

    local content = self:Read(src)
    if not content then return false end
    return self:Write(dst, content)
end

function VFS:Move(src: string, dst: string): boolean
    if not self.mounted then return false end

    if not self:Copy(src, dst) then return false end
    return self:Remove(src)
end

return VFS
