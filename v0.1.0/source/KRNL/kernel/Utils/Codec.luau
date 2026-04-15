local Codec = {}

local LibDeflate = require("/KRNL/kernel/Utils/LibDeflate")

local Prefix = "[CODEC]:"

-- ════════════════════════════════════
--  Serializer (Lua table  string)
-- ════════════════════════════════════

local function _serialize(val, indent)
    indent = indent or 0
    local t = type(val)

    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "number" then
        if val == math.floor(val) then
            return tostring(math.floor(val))
        else
            return string.format("%.10g", val)
        end
    elseif t == "string" then
        return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif t == "table" then
        local parts = {}
        local is_array = true
        local max_i    = 0
				
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                is_array = false
                break
            end
            if k > max_i then max_i = k end
        end

        if is_array and max_i == #val then
            for i = 1, #val do
                table.insert(parts, _serialize(val[i], indent + 1))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                local key
                if type(k) == "string" and k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
                    key = k
                else
                    key = "[" .. _serialize(k) .. "]"
                end
                table.insert(parts, key .. ":" .. _serialize(v, indent + 1))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        logWarning(string.format("%s Cannot serialize type: %s", Prefix, t))
        return "nil"
    end
end

-- ════════════════════════════════════
--  Deserializer (string  Lua table)
-- ════════════════════════════════════

local _pos = 1
local _src = ""

local function _peek()
    return _src:sub(_pos, _pos)
end

local function _advance()
    _pos += 1
end

local function _skip_ws()
    while _pos <= #_src and _src:sub(_pos, _pos):match("%s") do
        _pos += 1
    end
end

local function _parse_value()
    _skip_ws()
    local c = _peek()

    -- nil
    if _src:sub(_pos, _pos + 2) == "nil" then
        _pos += 3
        return nil

    -- boolean
    elseif _src:sub(_pos, _pos + 3) == "true" then
        _pos += 4
        return true
    elseif _src:sub(_pos, _pos + 4) == "false" then
        _pos += 5
        return false
		
    elseif c == '"' then
        _advance()
        local result = {}
        while _pos <= #_src do
            local ch = _peek()
            if ch == '"' then
                _advance()
                break
            elseif ch == '\\' then
                _advance()
                local esc = _peek()
                _advance()
                if     esc == 'n'  then table.insert(result, '\n')
                elseif esc == 'r'  then table.insert(result, '\r')
                elseif esc == 't'  then table.insert(result, '\t')
                elseif esc == '\\' then table.insert(result, '\\')
                elseif esc == '"'  then table.insert(result, '"')
                else                    table.insert(result, esc)
                end
            else
                table.insert(result, ch)
                _advance()
            end
        end
        return table.concat(result)
		
    elseif c:match("[%-%d]") then
        local num_str = _src:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", _pos)
        _pos += #num_str
        return tonumber(num_str)
    elseif c == '[' then
        _advance()
        local arr = {}
        _skip_ws()
        if _peek() == ']' then
            _advance()
            return arr
        end
        while _pos <= #_src do
            table.insert(arr, _parse_value())
            _skip_ws()
            local nc = _peek()
            if nc == ']' then
                _advance()
                break
            elseif nc == ',' then
                _advance()
            end
        end
        return arr
		
    elseif c == '{' then
        _advance()
        local obj = {}
        _skip_ws()
        if _peek() == '}' then
            _advance()
            return obj
        end
        while _pos <= #_src do
            _skip_ws()
            local key
            if _peek() == '[' then
                _advance()
                key = _parse_value()
                _skip_ws()
                _advance() -- ']'
            else
                local id = _src:match("^[a-zA-Z_][a-zA-Z0-9_]*", _pos)
                if id then
                    key = id
                    _pos += #id
                end
            end
            _skip_ws()
            _advance() -- ':'
            local val = _parse_value()
            obj[key]  = val
            _skip_ws()
            local nc = _peek()
            if nc == '}' then
                _advance()
                break
            elseif nc == ',' then
                _advance()
            end
        end
        return obj
    end

    return nil
end

local function _deserialize(str)
    _pos = 1
    _src = str
    return _parse_value()
end

-- ════════════════════════════════════
--  Public API
-- ════════════════════════════════════

local DEFAULT_LEVEL = { level = 5 }

function Codec.Encode(data, level): string?
    local ok, serialized = pcall(_serialize, data)
    if not ok then
        logWarning(string.format("%s Serialize error: %s", Prefix, serialized))
        return nil
    end

    local compressed = LibDeflate:CompressDeflate(serialized, level or DEFAULT_LEVEL)
    if not compressed then
        logWarning(string.format("%s Compression failed", Prefix))
        return nil
    end

    return LibDeflate:EncodeForPrint(compressed)
end

function Codec.Decode(str: string): any
    if not str or str == "" then return nil end

    local compressed = LibDeflate:DecodeForPrint(str)
    if not compressed then
        logWarning(string.format("%s DecodeForPrint failed", Prefix))
        return nil
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        logWarning(string.format("%s Decompression failed", Prefix))
        return nil
    end

    local ok, result = pcall(_deserialize, serialized)
    if not ok then
        logWarning(string.format("%s Deserialize error: %s", Prefix, result))
        return nil
    end

    return result
end

function Codec.Serialize(data): string
    return _serialize(data)
end

function Codec.Deserialize(str: string): any
    return _deserialize(str)
end

function Codec.Stats(data): (number, number, number)
    local serialized  = _serialize(data)
    local compressed  = LibDeflate:CompressDeflate(serialized, DEFAULT_LEVEL)
    local encoded     = LibDeflate:EncodeForPrint(compressed)
    local ratio       = math.floor((1 - #encoded / #serialized) * 100)
    return #serialized, #encoded, ratio
end

return Codec
