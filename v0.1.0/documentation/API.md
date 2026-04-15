# 📚 KRNL v0.1.0 System Call Reference

This documentation covers the public API (Syscalls) available in **KRNL Core**. All interactions with the kernel should be performed through the `KRNL` module.

---

## 🚀 Process Management
The Scheduler manages the lifecycle of all software running on the kernel.

### `KRNL.CreateTask(config: TaskConfig): Task`
Registers a new task in the system. The task is created in the `idle` state and will not run until started.
* **config**: `TaskConfig` table.
* **Returns**: `Task` object.

### `KRNL.LaunchTask(config: TaskConfig): Task`
A high-level function that creates a task and immediately sets its state to `running`.
* **config**: `TaskConfig` table.
* **Returns**: `Task` object.

### `KRNL.KillTask(pid: string)`
Terminates a task and removes it from the process registry.
* **pid**: The unique 6-character Process ID.

---

## 🔌 Driver & Hardware API
KRNL abstracts physical Retro Gadgets components into software drivers.

### `KRNL.GetDriver(name: string): Driver?`
Fetches a driver instance by its component name.
* **Supported Names**: `CPU`, `Lcd`, `KeyboardChip`, `VideoChip`, `ROM`, `Led`, `LedButton`, `Switch`, `Slider`, `RealityChip`, `FlashMemory`.
* **Note**: If multiple components exist, use `Name0`, `Name1`, etc.

### `KRNL.GetVFS(name: string): VFSInstance?`
Retrieves a Virtual File System instance associated with a storage device.
* **name**: The name of the FlashMemory driver (e.g., `"FlashMemory0"`).

### `KRNL.GetUtility(name: string): any`
Accesses built-in kernel utility modules.
* **Utilities**:
    * `Color4`: RGBA color management.
    * `BetterEvents`: Signal/Event system for inter-process communication.

---

## 🛠️ System Control

### `KRNL.Update()`
**CRITICAL:** This method must be called within the global `update()` function of your gadget. It drives the process scheduler and hardware driver updates.

```lua
function update()
    KRNL.Update()
end
