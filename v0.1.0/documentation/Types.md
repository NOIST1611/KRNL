# KRNL v0.1.0 Type Definitions

This document provides a complete reference for Luau types used within the KRNL.

---

## System & Task Types

### `Task`
The object representing a living process.
* `pid: string`: Unique 6-character identifier.
* `name: string`: Human-readable task name.
* `data: { [any]: any }`: Persistent task storage.
* `state: "running" | "idle"`: Execution status.
* `Update: ((self: Task) -> ())?`: The task's tick function.

### `TaskConfig`
Configuration used to initialize a task.
* `name: string?`
* `Data: { [any]: any }?`
* `UpdateFunction: ((self: Task) -> ())?`

---

## Virtual File System (VFS)

### `NodeType`
`"file" | "directory"`

### `Node`
A single entry in the VFS tree.
* `name: string`
* `type: NodeType`
* `content: string?`: File data (nil for directories).
* `children: { [string]: Node }?`: Directory contents.
* `size: number`: Bytes.
* `modified: number`: Timestamp.

### `VFSInstance`
The object managing a mounted storage device.
* `Mount()`: Mounts the storage to the kernel.
* `Commit()`: Flushes changes to physical FlashMemory.
* `Read/Write(path, content)`: Standard I/O.
* `ReadTable/WriteTable(path, data)`: Serialization of Lua tables.
* `Stat(path)`: Returns `Node` info for a path.

---

## Driver Base Types

### `Driver`
The base interface for all hardware abstractions.
* `instance: any`: The raw GDT component.
* `_driverData: BaseDriverData`: Metadata including `instance_name`.
* `_update: (self: Driver) -> ()`: Internal update logic.

---

## Drivers

### `CPUDriver`
Standardized access to system time and performance.
* `GetDeltaTime()`: Time since last tick.
* `GetRuntime()`: Total uptime.
* `GetTPS()`: Ticks per second.
* `GetUsage()`: CPU load %.
* `Delay(callback, time, ...args)`: Schedules a function call.

### `VideoDriver`
Powerful 2D/3D graphics and shader interface.
* `GetSize()`: Returns `(width, height)`.
* `Clear(color)` / `SetPixel(x, y, color)`.
* `DrawMesh(mesh)` / `DrawMeshTextured(mesh, tex)`.
* `SetVertexShader(fn)` / `SetFragmentShader(fn)`.
* `GetTouchPosition()`: Returns `(x, y)`.

### `LcdDriver`
Interface for text-based displays.
* `SetText(string)` / `PrintLine(line, text)`.
* `SetTextColor(color)` / `SetBackgroundColor(color)`.

### `KeyboardDriver`
* `GetBuffer()`: Returns the current input string.
* `IsKeyHeld(key)`: Real-time key state.
* `Flush()`: Clears the buffer.

### `RealityDriver`
Interface for host system metrics and asset loading.
* `GetRAMAvailable()`, `GetRAMUsed()`, `GetRAMTotal()`.
* `GetDateTime()`: Returns `RealityDateTime` table.
* `LoadSprite(filename, sw, sh)`: Loads external assets.

### `FlashMemoryDriver`
* `GetUsage()`: Returns `(bytes, unit, percentage)`.
* `Save(data)` / `Load()`: Low-level block storage.

---

## Registry Types

| Type | Definition |
| :--- | :--- |
| `TaskRegistry` | `{ [string]: Task }` |
| `DriverRegistry` | `{ [string]: Driver }` |
| `VFSRegistry` | `{ [string]: VFSInstance }` |

---

## Kernel Singleton
The main object managed by the kernel.
* `tasks: TaskRegistry`
* `drivers: DriverRegistry`
* `vfs: VFSRegistry`
* `_flags: KernelFlags`

---
> **Note:** For specific utility types like `Color4` or `BetterEvents`, refer to the official documentation of these utilities.
