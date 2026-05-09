# Virtual File System (VFS)

The **Virtual File System** is KRNL's primary storage management sub-system. It operates on top of the `FlashMemoryDriver` and provides a Linux-like directory structure with full file and directory management.

---

## Overview

VFS provides an in-memory file system tree that is persisted to FlashMemory. Each FlashMemory component in the gadget automatically gets its own VFS instance. The first FlashMemory detected during boot is designated as the **primary** VFS.

**Key features in v0.2.0:**

* Full CRUD file operations (read, write, copy, move, delete).
* Directory hierarchy with creation, listing, and recursive deletion.
* Automatic FlashMemory persistence via `Commit()`.
* File execution delegation to the Execution Handler.
* Table serialization/deserialization for structured data storage.
* Multiple VFS instances (one per FlashMemory component).

---

## Getting Started

```lua
local KRNL = require("/KRNL/OS")

-- Access primary VFS (recommended)
local fs = KRNL.GetPrimaryVFS()
if not fs then
    print("VFS not found — no FlashMemory component!")
end

-- Or access by name
local fs = KRNL.GetVFS("FlashMemory0")
```

---

## Core API Reference

### File Operations

#### `fs:Write(path: string, content: string): boolean`

Writes text data to a file. Creates the file if it doesn't exist, or overwrites it if it does. Automatically calls `Commit()` to persist to FlashMemory.

```lua
fs:Write("/home/greeting.txt", "Hello, World!")
fs:Write("/system/config.cfg", "theme=dark\nvolume=80")
```

#### `fs:Read(path: string): string?`

Reads the content of a file. Returns `nil` if the path is a directory or doesn't exist.

```lua
local content = fs:Read("/home/greeting.txt")
if content then
    print(content)  -- "Hello, World!"
end
```

#### `fs:WriteTable(path: string, data: table): boolean`

Serializes a Lua table to a string and saves it to a file. Uses the built-in `Codec.Serialize()` method.

```lua
fs:WriteTable("/system/settings.dat", {
    theme = "dark",
    volume = 80,
    language = "en"
})
```

#### `fs:ReadTable(path: string): table?`

Reads a file and deserializes its content back into a Lua table. Returns `nil` if the file doesn't exist or deserialization fails.

```lua
local settings = fs:ReadTable("/system/settings.dat")
if settings then
    print("Theme: " .. settings.theme)
    print("Volume: " .. tostring(settings.volume))
end
```

#### `fs:Execute(path: string): (boolean, string?)` *[Updated in v0.2.0]*

Executes a file using the **Execution Handler**. The file extension determines which handler is used (sync or async mode).

* For **sync** handlers: the file content is executed inline.
* For **async** handlers: a new task is created and launched.
* Returns `success` (boolean) and an optional error message.

```lua
-- Execute a shell script (sync)
local ok, err = fs:Execute("/system/init.kss")

-- Execute a Lua app (async — creates a task)
local ok, err = fs:Execute("/bin/my_app.lua")
```

> For unified execution with more control, use `KRNL.Execute(vfs, path, killOnFinish)` instead, which returns the created task for async modes.

---

### Directory & Navigation

#### `fs:List(path: string): { string }?`

Returns a sorted array of names within a directory. Directories are suffixed with `/` for easy identification.

```lua
local items = fs:List("/home")
if items then
    for _, name in ipairs(items) do
        print(name)  -- "documents/", "notes.txt"
    end
end
```

#### `fs:MakeDir(path: string): boolean`

Creates a new directory. Returns `false` if the path already exists or the parent directory is invalid. Automatically calls `Commit()`.

```lua
fs:MakeDir("/home/documents")
fs:MakeDir("/home/documents/projects")
```

#### `fs:Exists(path: string): boolean`

Checks if a node (file or directory) exists at the given path.

```lua
if fs:Exists("/system/config.cfg") then
    print("Config file exists")
end
```

#### `fs:IsDir(path: string): boolean`

Returns `true` if the node at the path is a directory.

#### `fs:IsFile(path: string): boolean`

Returns `true` if the node at the path is a file.

```lua
if fs:IsDir("/home") then
    local items = fs:List("/home")
end

if fs:IsFile("/system/config.cfg") then
    local content = fs:Read("/system/config.cfg")
end
```

---

### File Management

#### `fs:Remove(path: string): boolean`

Removes a file or an **empty** directory. Returns `false` if the directory is not empty. Automatically calls `Commit()`.

```lua
fs:Remove("/tmp/cache.txt")
fs:Remove("/tmp/old_folder")  -- Only works if folder is empty
```

#### `fs:RemoveAll(path: string): boolean`

Recursively removes a node and **all** of its children. Use with caution — this cannot be undone. Automatically calls `Commit()`.

```lua
fs:RemoveAll("/tmp/old_data")
```

#### `fs:Copy(src: string, dst: string): boolean`

Copies file content from the source path to the destination path. Only works for files (not directories).

```lua
fs:Copy("/system/config.cfg", "/home/config_backup.cfg")
```

#### `fs:Move(src: string, dst: string): boolean`

Moves or renames a file/directory. Uses Copy + Remove logic internally. Automatically calls `Commit()`.

```lua
fs:Move("/home/old_name.txt", "/home/new_name.txt")
fs:Move("/tmp/download.dat", "/home/documents/download.dat")
```

#### `fs:Stat(path: string): Node?`

Returns the raw Node object (metadata) for the given path. Nodes have the following fields:

| Field | Type | Description |
|---|---|---|
| `name` | string | Node name. |
| `type` | string | `"file"` or `"directory"`. |
| `content` | string? | File content (`nil` for directories). |
| `children` | table? | Child nodes (`nil` for files). |
| `size` | number | Content size in bytes. |
| `modified` | number | Modification timestamp. |

```lua
local node = fs:Stat("/home/greeting.txt")
if node then
    print("Name: " .. node.name)
    print("Type: " .. node.type)
    print("Size: " .. node.size .. " bytes")
end
```

#### `fs:Commit(): boolean`

Manually flushes the current VFS state to the Flash Memory component. This is called automatically by write operations, but can be called manually for explicit persistence control.

```lua
-- Write multiple files, then commit once
fs:Write("/file1.txt", "data1")  -- auto-commits
fs:Write("/file2.txt", "data2")  -- auto-commits
-- No need for manual Commit unless you modify internal state directly
```

---

## Default System Structure

Upon a fresh mount, the primary VFS initializes the following directory hierarchy:

```
/
├── bin/              — System binaries and executables
├── system/
│   ├── config.cfg    — System configuration (serialized table)
│   ├── init.kss      — Startup script (KRNL INIT SCRIPT)
│   └── recovery.kss  — Recovery script for fixing broken init
├── home/             — User-specific data and local files
└── tmp/              — Temporary volatile data
```

### Default Files

**`/system/config.cfg`** — System configuration stored as a serialized table:

```lua
-- Default contents (serialized):
{
    theme = "default",
    version = "0.2.0"
}
```

**`/system/init.kss`** — Boot script executed when KRNL NANO starts:

```
# KRNL INIT SCRIPT
clear
echo KRNL NANO booted.
echo type 'help' for commands.
```

**`/system/recovery.kss`** — Recovery script that recreates the init file if it gets corrupted:

```
# KRNL RECOVERY SCRIPT
touch /system/init.kss
append /system/init.kss # KRNL INIT SCRIPT
append /system/init.kss clear
append /system/init.kss echo KRNL NANO booted.
append /system/init.kss echo type 'help' for commands.
reboot
```

---

## Code Examples

### File Management Utilities

```lua
local fs = KRNL.GetPrimaryVFS()

-- Backup a config file
if fs:Exists("/system/config.cfg") then
    fs:Copy("/system/config.cfg", "/home/config_backup.cfg")
    print("Config backed up!")
end

-- Clean up temporary files
if fs:IsDir("/tmp/old_data") then
    fs:RemoveAll("/tmp/old_data")
    print("Temp files cleaned!")
end

-- Read structured settings
local settings = fs:ReadTable("/system/config.cfg")
if settings then
    settings.theme = "dark"
    fs:WriteTable("/system/config.cfg", settings)
    print("Settings updated!")
end
```

### Safe File Operations

```lua
local function safeWrite(path, content)
    -- Write to temp first, then move
    local tempPath = "/tmp/write_temp"
    if fs:Write(tempPath, content) then
        if fs:Exists(path) then
            fs:Remove(path)
        end
        fs:Move(tempPath, path)
        return true
    end
    return false
end
```

---

## Limitations & Performance

* **FlashMemory Size:** The total size of all files must fit within the FlashMemory component's capacity. Attempting to commit beyond this limit will fail with a warning.
* **No Symbolic Links:** VFS does not support symlinks, hard links, or mount points.
* **Single-Level Copy:** `Copy` only works for files, not directories. Use a manual loop for directory copies.
* **Commit Frequency:** Every write operation triggers a `Commit()`. For bulk operations, consider building a helper that batches changes and commits once.
