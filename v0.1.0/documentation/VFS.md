
---

# Virtual File System (VFS)

The **Virtual File System** is KRNL's primary storage management sub-system. It operates on top of the `FlashMemoryDriver` and provides a Linux-like directory structure.

---

## Getting Started

To start working with VFS, you first need to retrieve it through the sycall API.

```lua
local KRNL = require("/KRNL/OS")
local fs = KRNL.GetPrimaryVFS() -- Returns main VFS which is used

if not fs then
    print("VFS not found!")
end
```

---

## Core API Reference

### File Operations

#### `fs:Write(path: string, content: string): boolean`
Writes text data to a file. Creates the file if it doesn't exist. Automatically calls `Commit()`.

#### `fs:Read(path: string): string?`
Reads the content of a file. Returns `nil` if the path is a directory or doesn't exist.

#### `fs:WriteTable(path: string, data: table): boolean`
Serializes a Lua table and saves it to a file.

#### `fs:ReadTable(path: string): table?`
Reads a file and deserializes its content back into a Lua table.

#### `fs:Execute(path: string): (boolean, string?)`
Reads the file content and passes it to the `ExecutionHandler` for execution.

---

### Directory & Navigation

#### `fs:List(path: string): { string }?`
Returns an array of names within a directory.
* **Format:** Directories are suffixed with `/` (e.g., `["bin/", "config.cfg"]`).

#### `fs:MakeDir(path: string): boolean`
Creates a new directory. Returns `false` if the path already exists or parent is invalid.

#### `fs:Exists(path: string): boolean`
Checks if a node (file or directory) exists at the given path.

#### `fs:IsDir(path: string): boolean` / `fs:IsFile(path: string): boolean`
Returns `true` if the node at the path matches the specified type.

---

### File Management

#### `fs:Remove(path: string): boolean`
Removes a file or an **empty** directory.

#### `fs:RemoveAll(path: string): boolean`
Recursively removes a node and all of its children. **Use with caution.**

#### `fs:Copy(src: string, dst: string): boolean`
Copies file content from the source path to the destination path.

#### `fs:Move(src: string, dst: string): boolean`
Moves or renames a file/directory. Uses Copy + Remove logic.

#### `fs:Stat(path: string): Node?`
Returns the raw Node object (metadata) for the given path.

#### `fs:Commit(): boolean`
Manually flushes the current VFS state to the Flash Memory component.

---

## Default System Structure
Upon a fresh mount, VFS initializes the following hierarchy:

* `/bin/` — System binaries and executables.
* `/system/` — Core configuration and system-level files.
* `/home/` — User-specific data and local files.
* `/tmp/` — Temporary volatile data.

---

## Code Example: VFS Utilities

```lua
local fs = KRNL.GetPrimaryVFS()

-- Quick check and copy
if fs:Exists("/system/config.cfg") then
    fs:Copy("/system/config.cfg", "/home/backup.cfg")
end

-- Directory cleanup
if fs:IsDir("/tmp/old_data") then
    fs:RemoveAll("/tmp/old_data")
end
```

---

## Limitations & Performance
* **Memory Constrain:** The total size of the VFS structure (files + metadata) is limited by the capacity of the hardware `FlashMemory`.
* **Traversal:** Deeply nested paths slightly increase search time due to recursive traversal.
