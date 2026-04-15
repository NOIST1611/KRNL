
-----

# 💾 FlashMemoryDriver Reference

The **FlashMemoryDriver** manages the `FlashMemory` component. It provides low-level information about storage capacity and usage.

### ⚠️ IMPORTANT: DEPRECATION NOTICE

The direct `Save` and `Load` methods in this driver are strictly for **internal kernel use**. Applications and users should **NEVER** use these methods directly, as doing so will bypass the KRNL File System, potentially corrupting the entire storage structure.

> **[Recommended Approach]**
> To store and retrieve data, use the **Virtual File System (VFS)**.
> 📁 [View VFS Documentation here](/v0.1.0/documentation/VFS.md)

-----

## 📥 Accessing the Driver

```lua
local KRNL = require("/KRNL/OS")
local flash = KRNL.GetDriver("FlashMemory0")
```

-----

## 📊 Storage Information

These methods allow you to monitor the health and capacity of the storage medium.

### `flash:GetSize(): (number, string)`

Returns the total capacity of the Flash component.

  * **Returns:** 1. `number`: Size in bytes.
    2\. `string`: Human-readable size (e.g., `"128 KB"`).

### `flash:GetUsage(): (number, string, number)`

Returns the current usage of the Flash component.

  * **Returns:**
    1.  `number`: Used bytes.
    2.  `string`: Human-readable used size (e.g., `"16 KB"`).
    3.  `number`: Usage percentage (`0` to `100`).

-----

## 🚫 Restricted Methods (Kernel Only)

The following methods are implemented but **SHOULD NOT** be used by standard applications. Use the [VFS](/v0.1.0/documentation/VFS.md) instead.

### `flash:Save(data: table)`

**DO NOT USE.** Overwrites the entire flash memory with encoded data.

  * **Risk:** This will erase all existing files managed by the VFS.

### `flash:Load(): table`

**DO NOT USE.** Reads the raw encoded block from the flash memory.

  * **Note:** This returns a raw decoded table, which is not useful without the VFS directory structure.

-----

## 💡 Code Example: Memory Monitor

If you are building a system dashboard, you should use the informational methods only:

```lua
local flash = KRNL.GetDriver("FlashMemory0")
local size, sizeStr = flash:GetSize()
local used, usedStr, percent = flash:GetUsage()

print("--- STORAGE STATUS ---")
print("Capacity: " .. sizeStr)
print("Used:     " .. usedStr .. " (" .. math.floor(percent) .. "%)")
```

-----

## ⚙️ Internal Logic

1.  **Safety Checks:** The `Save` method automatically checks if the encoded data size exceeds the hardware `instance.Size` before attempting to write.
2.  **Compression & Encoding:** The driver uses `Codec.Encode` and `Codec.Decode` internally to optimize space and ensure data integrity.
3.  **Human-Friendly Conversions:** All size calculations are piped through `SizeConverter` for consistent formatting across the OS.

-----
