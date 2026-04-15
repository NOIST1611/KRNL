
---

# 📂 Virtual File System (VFS)

The **Virtual File System** is KRNL's primary storage management sub-system. It operates on top of the `FlashMemoryDriver` and provides a Linux-like directory structure (`/bin`, `/etc`, `/home`).



---

## 🚀 Getting Started

To use the file system, you must first retrieve the VFS instance from the kernel. Most systems will have at least one primary VFS mounted to the main Flash Memory.

```lua
local KRNL = require("/KRNL/OS")
local fs = KRNL.GetVFS("FlashMemory0")

if not fs then
    print("VFS not found!")
end
```

---

## 🛠️ Core API Reference

### File Operations

#### `fs:Write(path: string, content: string): boolean`
Writes text data to a file. If the file doesn't exist, it will be created.
* **Commit Behavior:** Automatically triggers a `Commit()` to physical Flash.

#### `fs:Read(path: string): string?`
Reads the content of a file. Returns `nil` if the file is not found or is a directory.

#### `fs:WriteTable(path: string, data: table): boolean`
A helper that serializes a Lua table and saves it as a file.

#### `fs:ReadTable(path: string): table?`
Reads a file and deserializes its content back into a Lua table.

---

### Directory & Navigation

#### `fs:List(path: string): { string }?`
Returns an array of names (strings) within the specified directory.
* **Format:** Directories are suffixed with `/` (e.g., `["bin/", "config.cfg"]`).

#### `fs:MakeDir(path: string): boolean`
Creates a new directory. Returns `false` if the path already exists.

#### `fs:Exists(path: string): boolean`
Checks if a node (file or directory) exists at the given path.

---

### File Management

#### `fs:Remove(path: string): boolean`
Removes a file or an **empty** directory.

#### `fs:RemoveAll(path: string): boolean`
Recursively removes a directory and all of its contents. **Use with caution.**

#### `fs:Move(src: string, dst: string): boolean`
Renames or moves a file/directory from one path to another.

---

## 🏗️ Default System Structure
When KRNL is first booted with a clean Flash Memory, the VFS automatically initializes the following hierarchy:

* `/bin/` — System binaries and executables.
* `/system/` — Configuration files (aliased as `etc` in some logs).
* `/home/` — User-specific data.
* `/tmp/` — Volatile data (cleared manually, persistent between boots in this version).

---

## 💡 Code Example: App Configuration

```lua
local fs = KRNL.GetVFS("MainFS")
local configPath = "/home/myapp/settings.json"

-- Initial Setup
if not fs:Exists("/home/myapp") then
    fs:MakeDir("/home/myapp")
end

-- Save Data
local mySettings = { theme = "dark", volume = 0.8 }
fs:WriteTable(configPath, mySettings)

-- Read Data
local settings = fs:ReadTable(configPath)
if settings then
    print("Theme loaded: " .. settings.theme)
end
```

---

## ⚙️ Internal Mechanics (How it works)

### 1. Traversing
The VFS uses an internal `_traverse` helper that splits the path (e.g., `/home/user/file.txt`) and walks through the tree of nodes. It returns the target node, its parent, and its name.

### 2. The Commit Cycle
Unlike standard OSes that may cache writes in RAM for long periods, KRNL's VFS triggers a **Commit** on every write operation. 
1. The VFS updates the `self.root` table.
2. It sends the entire tree to `FlashMemoryDriver:Save()`.
3. The driver encodes and compresses the data before writing to the physical chip.

### 3. Serialization
The VFS uses the `Codec` utility to transform Lua tables into strings. This ensures that even complex nested tables can be stored as single files.

---

## ⚠️ Limitations & Performance
* **Storage Limit:** Since the entire root tree is saved at once, the total size of all files + the structure itself cannot exceed the capacity of your `FlashMemory` component.
* **Path Length:** Paths should be concise to ensure fast traversal.
---
