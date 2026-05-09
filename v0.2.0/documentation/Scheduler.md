# Task Scheduler

The **Scheduler** is KRNL's process management subsystem. It handles task creation, lifecycle management, and state transitions for all software running on the kernel.

---

## Overview

Every piece of executable software in KRNL runs as a **Task**. The Scheduler is responsible for creating tasks, assigning unique process identifiers (PIDs), tracking their state, and cleaning them up when they are terminated. Tasks are managed through a central registry that maps PIDs to task objects.

**Key features:**

* **Unique PID generation** — Every task receives a cryptographically generated 6-character PID via the PID Generator utility.
* **State management** — Tasks can be in one of two states: `idle` or `running`.
* **Centralized registry** — All tasks are stored in a shared table accessible through `KRNL.GetTasks()`.
* **Automatic crash recovery** — The kernel's update loop catches errors in task update functions and automatically kills crashed tasks.

---

## Task Lifecycle

```
CreateTask (idle) ──→ SetState("running") ──→ Update loop ──→ Kill
                                               │
                                               ├─ Error caught → auto-Kill
                                               └─ Running until killed
```

### States

| State | Description |
|---|---|
| `idle` | The task is registered in the system but will not be executed. The `UpdateFunction` is never called. |
| `running` | The task is active. Its `UpdateFunction` is called every tick inside `KRNL.Update()`. |

---

## Task Object

Each task is a table with the following fields:

| Field | Type | Description |
|---|---|---|
| `pid` | string | Unique 6-character process identifier (e.g., `"a3f8b1"`). |
| `name` | string | Human-readable task name. Defaults to `"unknown_task"`. |
| `data` | table | User-defined data table accessible inside the task's update function via `self.Data`. |
| `state` | `"idle"` \| `"running"` | Current task state. |
| `Update` | function? | The update function called every tick while the task is running. |

### Task Methods

Tasks also have methods inherited from the Scheduler metatable:

#### `task:SetState(state: "running" | "idle")`

Changes the task's state. Use this to pause or resume a task.

```lua
local task = KRNL.LaunchTask({ name = "worker", UpdateFunction = myFn })

-- Pause the task
task:SetState("idle")

-- Resume the task
task:SetState("running")
```

#### `task:Kill(registry: TaskRegistry)`

Terminates the task. Removes it from the registry, clears its metatable, and frees all associated data. This is called internally by `KRNL.KillTask(pid)`.

> **Note:** You should use `KRNL.KillTask(pid)` to kill tasks rather than calling `task:Kill()` directly, as the syscall handles registry access automatically.

---

## Syscall API

The Scheduler is accessed through the following syscalls on the `KRNL` module:

### `KRNL.CreateTask(config: TaskConfig): Task`

Creates a new task in the `idle` state. The task will not execute until its state is set to `running`.

* **config**: TaskConfig table (see below).
* **Returns**: `Task` object with a unique PID.

```lua
local task = KRNL.CreateTask({
    name = "my_task",
    UpdateFunction = function(self)
        -- Called every tick when running
        self.data.counter = (self.data.counter or 0) + 1
    end,
    Data = { counter = 0 }
})

print(task.pid)    -- e.g., "a3f8b1"
print(task.state)  -- "idle"
```

### `KRNL.LaunchTask(config: TaskConfig): Task`

Creates a task and immediately sets its state to `running`. The task begins executing on the next `KRNL.Update()` call.

* **config**: TaskConfig table.
* **Returns**: `Task` object.

```lua
local task = KRNL.LaunchTask({
    name = "clock",
    UpdateFunction = function(self)
        -- Runs every tick
    end,
    Data = { ticks = 0 }
})
print(task.state)  -- "running"
```

### `KRNL.GetTasks(): { [string]: Task }`

Returns the complete task registry. This is a table mapping PID strings to Task objects.

* **Returns**: `{ [pid]: Task }`.

```lua
local tasks = KRNL.GetTasks()
local count = 0
for pid, task in pairs(tasks) do
    print(string.format("[%s] %s (%s)", pid, task.name, task.state))
    count += 1
end
print("Total tasks: " .. count)
```

### `KRNL.KillTask(pid: string)`

Terminates a task by its PID. The task is removed from the registry and all its resources are freed. If a crashed callback is registered via IPC, `IPC.Cleanup(pid)` should be called separately.

* **pid**: The 6-character process ID.

```lua
KRNL.KillTask("a3f8b1")
```

---

## TaskConfig

The `TaskConfig` table defines how a task is created:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | No | Human-readable task name. Defaults to `"unknown_task"`. |
| `UpdateFunction` | function | No | Called every tick while the task is in `running` state. Receives `self` (the task object) as the first argument. |
| `Data` | table | No | User-defined data table. Accessible inside the update function via `self.data`. |

---

## Update Function

The update function is the core of every task. It is called once per tick (inside `KRNL.Update()`) while the task is in the `running` state.

```lua
local function myUpdate(self)
    -- self.pid    — task's PID
    -- self.name   — task's name
    -- self.data   — task's data table
    -- self.state  — current state

    self.data.counter = (self.data.counter or 0) + 1

    -- Access other tasks
    local tasks = KRNL.GetTasks()
    for pid, t in pairs(tasks) do
        if pid ~= self.pid then
            -- Interact with other tasks
        end
    end
end
```

### Error Handling

If the update function throws an error, the kernel catches it automatically:

1. A warning is logged: `[KRNL] Task <pid> crashed: <error message>`.
2. The task is added to the crash list.
3. After all tasks have been processed, all crashed tasks are automatically killed.

This prevents a single faulty task from crashing the entire kernel.

---

## PID Generator

PIDs are generated by the `PIDGenerator` utility (`Utils/PID`). Each PID is a 6-character random string, making collisions extremely unlikely.

```lua
-- PID example: "a3f8b1", "7c2de9", "f041ba"
```

PIDs are generated at task creation time and remain constant for the task's lifetime. Once a task is killed, its PID becomes available for reuse.

---

## Code Examples

### Basic Task

```lua
local KRNL = require("/KRNL/OS")

-- Create and launch a simple counter task
local task = KRNL.LaunchTask({
    name = "counter",
    UpdateFunction = function(self)
        self.data.count = (self.data.count or 0) + 1
    end,
    Data = { count = 0 }
})

-- Later, check the counter
local t = KRNL.GetTasks()[task.pid]
if t then
    print("Count: " .. t.data.count)
end
```

### Task with IPC Cleanup

```lua
local IPC = KRNL.GetIPC()

local task = KRNL.LaunchTask({
    name = "listener",
    UpdateFunction = function(self)
        -- Process data
    end,
    Data = {}
})

-- Register IPC listener for this task
IPC.Listen("my.event", function(data)
    print("Event received: " .. data.message)
end, { taskID = task.pid })

-- Kill task and clean up its IPC listeners
KRNL.KillTask(task.pid)
IPC.Cleanup(task.pid)
```

### Task State Management

```lua
local task = KRNL.CreateTask({
    name = "conditional_worker",
    UpdateFunction = function(self)
        self.data.workDone = (self.data.workDone or 0) + 1
        if self.data.workDone >= 100 then
            task:SetState("idle")
            print("Work complete — task paused")
        end
    end,
    Data = { workDone = 0 }
})

-- Start when ready
task:SetState("running")
```

### Enumerate Running Tasks

```lua
local function printTaskList()
    local tasks = KRNL.GetTasks()
    print("=== Task List ===")
    for pid, task in pairs(tasks) do
        local state = task.state == "running" and "RUN" or "IDLE"
        print(string.format("  [%s] %-20s %s", pid, task.name, state))
    end
    print("==================")
end
```

---

## Limitations

* **No priority scheduling** — All running tasks are executed in arbitrary order within the same tick. There is no priority or time-slicing system.
* **No sleep/wait** — There is no built-in mechanism to delay or suspend a task for a specific duration. Use counters and state checks instead.
* **Manual IPC cleanup** — The kernel does not automatically clean up IPC listeners when a task is killed. You must call `IPC.Cleanup(pid)` manually.
