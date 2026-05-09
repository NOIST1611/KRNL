# KRNL v0.2.0 System Call Reference

This documentation covers the public API (Syscalls) available in **KRNL v0.2.0**. All interactions with the kernel should be performed through the `KRNL` module, which is obtained via:

```lua
local KRNL = require("/KRNL/OS")
```

---

## Process Management

The Scheduler manages the lifecycle of all software running on the kernel. Every task is assigned a unique 6-character PID and can be in one of two states: `idle` or `running`.

### `KRNL.CreateTask(config: TaskConfig): Task`

Registers a new task in the system. The task is created in the `idle` state and will not run until its state is manually set to `running`.

* **config**: `TaskConfig` table.
    * `name` *(string)* — Human-readable task name.
    * `UpdateFunction` *(function)* — Called every tick while the task is running.
    * `Data` *(table)* — Optional data table accessible inside the task.
* **Returns**: `Task` object.

```lua
local task = KRNL.CreateTask({
    name = "my_task",
    UpdateFunction = function(self)
        -- Task logic here
    end,
    Data = { counter = 0 }
})
```

### `KRNL.LaunchTask(config: TaskConfig): Task`

A high-level function that creates a task and immediately sets its state to `running`. The task will begin executing on the next `KRNL.Update()` call.

* **config**: `TaskConfig` table.
* **Returns**: `Task` object.

```lua
local task = KRNL.LaunchTask({
    name = "background_worker",
    UpdateFunction = function(self)
        self.Data.counter = (self.Data.counter or 0) + 1
    end,
    Data = { counter = 0 }
})
```

### `KRNL.GetTasks(): { [string]: Task }`

Returns the complete task registry — a table mapping PID strings to `Task` objects. Useful for inspecting running tasks, counting active processes, or iterating over all tasks.

* **Returns**: Table `{ [pid]: Task }`.

```lua
local tasks = KRNL.GetTasks()
for pid, task in pairs(tasks) do
    print(pid .. " | " .. task.name .. " | " .. task.state)
end
```

### `KRNL.KillTask(pid: string)`

Terminates a task and removes it from the process registry. All resources associated with the task are freed.

* **pid**: The unique 6-character Process ID.

```lua
KRNL.KillTask("a1b2c3")
```

---

## Driver & Hardware API

KRNL abstracts Retro Gadgets components into software drivers. In v0.2.0, the following hardware components are supported:

| Driver Name | Component | Description |
|---|---|---|
| `CPU` | CPU Chip | Central processing unit (CPU0, CPU1, ...) |
| `Lcd` | LCD Display | Screen output (Lcd0, Lcd1, ...) |
| `KeyboardChip` | Keyboard Chip | Keyboard input |
| `VideoChip` | Video Chip | Advanced video rendering |
| `ROM` | ROM Chip | Read-only memory storage |
| `Led` | LED | LED indicator |
| `LedButton` | LED Button | Button with LED feedback |
| `Switch` | Switch | Toggle switch input |
| `Slider` | Slider | Analog slider input |
| `RealityChip` | Reality Chip | 3D rendering |
| `FlashMemory` | Flash Memory | Persistent storage (drives VFS) |
| `AudioChip` | Audio Chip | **[NEW in v0.2.0]** Audio playback |
| `Wifi` | Wifi Chip | **[NEW in v0.2.0]** Network connectivity |

### `KRNL.GetDriver(name: string): Driver?`

Fetches a driver instance by its component instance name (e.g., `"CPU0"`, `"Lcd0"`, `"FlashMemory0"`).

* **name**: The instance name of the component as assigned in Retro Gadgets.
* **Returns**: `Driver` object or `nil` if not found.

```lua
local lcd = KRNL.GetDriver("Lcd0")
if lcd then
    lcd.instance:SetText("Hello!")
end
```

### `KRNL.GetUtility(name: string): any`

Accesses built-in kernel utility modules.

* **name**: Name of the utility.
* **Returns**: The utility module or `nil`.

**Available utilities:**

| Name | Description |
|---|---|
| `Color4` | RGBA color management utility. |
| `BetterEvents` | Signal/Event system for inter-process communication (legacy). |
| `SizeConverter` | File size formatting (bytes to human-readable). |
| `IPC` | **[NEW]** Inter-Process Communication pub/sub event bus. |
| `ExecutionHandler` | **[NEW]** Pluggable file format execution system. |

```lua
local Color4 = KRNL.GetUtility("Color4")
local IPC = KRNL.GetUtility("IPC")
```

---

## Virtual File System (VFS) API

### `KRNL.GetVFS(name: string): VFSInstance?`

Retrieves a Virtual File System instance associated with a specific FlashMemory component.

* **name**: The driver instance name (e.g., `"FlashMemory0"`).
* **Returns**: `VFSInstance` or `nil`.

### `KRNL.GetPrimaryVFS(): VFSInstance?`  *[NEW in v0.2.0]*

Returns the primary VFS instance — the first FlashMemory that was detected during boot. This is a convenience method so you don't need to remember the exact driver name.

* **Returns**: `VFSInstance` or `nil` if no FlashMemory was found.

```lua
local fs = KRNL.GetPrimaryVFS()
if fs then
    fs:Write("/home/test.txt", "Hello World")
end
```

> For the complete VFS API reference (file operations, directory management, etc.), see [VFS.md](./VFS.md).

---

## Network (NET) API

### `KRNL.GetNET(name: string): NETInstance?`  *[NEW in v0.2.0]*

Retrieves a NET instance associated with a specific Wifi component.

* **name**: The Wifi driver instance name (e.g., `"Wifi0"`).
* **Returns**: `NETInstance` or `nil`.

### `KRNL.GetPrimaryNET(): NETInstance?`  *[NEW in v0.2.0]*

Returns the primary NET instance — the first Wifi component detected during boot.

* **Returns**: `NETInstance` or `nil` if no Wifi was found.

```lua
local NET = KRNL.GetPrimaryNET()
if NET then
    NET:Get("https://example.com/api/data", function(response)
        if response.ok then
            print("Data: " .. response.text)
        end
    end)
end
```

> For the complete NET API reference (HTTP methods, caching, interceptors, etc.), see [NET.md](./NET.md).

---

## Inter-Process Communication (IPC) API

### `KRNL.GetIPC(): IPCInterface`  *[NEW in v0.2.0]*

Returns the global IPC interface for pub/sub event-based communication between tasks.

* **Returns**: `IPCInterface`.

```lua
local IPC = KRNL.GetIPC()

IPC.Listen("system.boot", function(data)
    print("System booted!")
end)

IPC.Post("system.boot", { time = os.time() })
```

> For the complete IPC API reference (wildcards, priority, cleanup, etc.), see [IPC.md](./IPC.md).

---

## Execution Handler API

### `KRNL.GetExecutionHandler(): ExecutionHandlerInterface`  *[NEW in v0.2.0]*

Returns the Execution Handler module for registering and managing custom file format handlers.

* **Returns**: `ExecutionHandlerInterface`.

```lua
local Exec = KRNL.GetExecutionHandler()

Exec.RegisterFormat(".myext", function(content, path, config)
    -- Parse and execute custom format
    print("Running: " .. path)
end, "sync")
```

> For the complete Execution Handler API reference, see [ExecutionHandler.md](./ExecutionHandler.md).

---

## File Execution

### `KRNL.Execute(vfs: VFSInstance, path: string, killOnFinish: boolean): (boolean, string?, Task?)`  *[NEW in v0.2.0]*

A unified entry point for executing files from the VFS. Automatically determines the correct execution strategy based on the file extension and the registered Execution Handler.

* **vfs**: The VFS instance to read the file from.
* **path**: Path to the file within the VFS (e.g., `"/bin/script.lua"`).
* **killOnFinish**: *(Currently unused, reserved for future use)*.
* **Returns**: `success` (boolean), `errorMessage` (string or nil), `task` (Task object for async modes, nil for sync).

**Execution flow:**

1. Reads the file content from the VFS.
2. Extracts the file extension.
3. Looks up the registered Execution Handler for that extension.
4. If the handler mode is `"async"`:
    * Calls the handler to get a task configuration.
    * Creates and launches a new task via `KRNL.LaunchTask()`.
    * Returns the task object.
5. If the handler mode is `"sync"` (or no handler found):
    * Delegates to `vfs:Execute(path)` for inline execution.
    * No task is created.

```lua
local fs = KRNL.GetPrimaryVFS()

-- Execute a Lua script (async - runs as a background task)
local ok, err, task = KRNL.Execute(fs, "/bin/my_app.lua", false)
if ok then
    print("Task started: " .. task.pid)
else
    print("Error: " .. err)
end

-- Execute a shell script (sync - runs inline)
local ok, err = KRNL.Execute(fs, "/system/init.kss", false)
```

---

## System Control

### `KRNL.Update()`  *[CRITICAL]*

**This method must be called within the global `update()` function of your gadget.** It drives the entire kernel loop:

1. Runs all active tasks (crashed tasks are automatically killed).
2. Updates all hardware drivers.
3. Updates all NET instances (processes timeouts, retries, and queued requests).

```lua
function update()
    KRNL.Update()
end
```

> **WARNING:** Failure to call `KRNL.Update()` will result in no tasks executing, no drivers updating, and no network requests being processed.

---

## Type Reference

The following types are exported from the `KRNL` module and can be used for type annotations in Luau:

| Type | Description |
|---|---|
| `KernelSingleton` | The internal kernel singleton object. |
| `Driver` | Generic driver wrapper. |
| `CPUDriver` | CPU component driver. |
| `LCDDriver` | LCD display driver. |
| `Task` | Process/task object with PID, state, and update function. |
| `TaskConfig` | Configuration table for creating tasks. |
| `Color` | RGBA color value (from Color4 utility). |
| `KeyboardDriver` | Keyboard input driver. |
| `VideoDriver` | Video chip driver. |
| `VideoTexture` | Video texture handle. |
| `RomDriver` | ROM chip driver. |
| `LedDriver` | LED driver. |
| `LedButtonDriver` | LED button driver. |
| `SwitchDriver` | Switch driver. |
| `SliderDriver` | Slider driver. |
| `RealityDriver` | Reality chip (3D) driver. |
| `FlashMemoryDriver` | Flash memory storage driver. |
| `AudioDriver` | **[NEW]** Audio chip driver. |
| `WifiDriver` | **[NEW]** Wifi network driver. |
| `VFSInstance` | Virtual File System instance. |
| `NETInstance` | **[NEW]** Network client instance. |
| `IPCInterface` | **[NEW]** Inter-Process Communication interface. |
| `ExecutionHandlerInterface` | **[NEW]** File execution handler interface. |
