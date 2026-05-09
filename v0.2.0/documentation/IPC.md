# Inter-Process Communication (IPC)

The **IPC** module is KRNL's pub/sub event system for inter-task communication. It allows tasks to communicate asynchronously by publishing and subscribing to events, without requiring direct references between them.

---

## Overview

IPC follows the **publish/subscribe** pattern. Tasks register *listeners* for specific event names, and any part of the system can *post* events to trigger those listeners. This decouples tasks from each other and enables flexible, event-driven architectures.

**Key features:**

* **Wildcard patterns** — Subscribe to event families using `*` (e.g., `"sys.*"` matches `"sys.boot"`, `"sys.error"`, etc.).
* **Priority-based dispatch** — Listeners are called in priority order (lower number = higher priority).
* **One-time listeners** — Subscribe to an event and automatically unsubscribe after the first trigger.
* **Per-task cleanup** — Remove all listeners associated with a specific task ID when the task is killed.

---

## Accessing IPC

```lua
local KRNL = require("/KRNL/OS")
local IPC = KRNL.GetIPC()
-- or
local IPC = KRNL.GetUtility("IPC")
```

---

## Core API Reference

### `IPC.Listen(event: string, callback: function, options: table?)`

Registers a listener for the given event pattern. The listener will be called whenever an event is posted that matches the pattern.

* **event**: The event name or pattern. Supports wildcards (`*`) for matching multiple events.
* **callback**: Function `(data: any, event: string)` called when a matching event is posted.
* **options**: Optional configuration table.
    * `taskID` *(string)* — Identifier of the owning task. Defaults to `"kernel"`. Used for cleanup.
    * `priority` *(number)* — Dispatch priority. Lower numbers execute first. Defaults to `100`.
    * `once` *(boolean)* — If `true`, the listener is automatically removed after its first invocation. Defaults to `false`.

```lua
-- Basic listener
IPC.Listen("user.login", function(data, event)
    print("User logged in: " .. data.username)
end)

-- Wildcard listener — catches all "system.*" events
IPC.Listen("system.*", function(data, event)
    print("System event: " .. event)
end)

-- One-time listener — fires once, then auto-removes
IPC.Listen("file.saved", function(data, event)
    print("File saved: " .. data.path)
end, { once = true })

-- High-priority listener
IPC.Listen("input.key", function(data, event)
    -- Process key input first
end, { priority = 10, taskID = myTask.pid })
```

---

### `IPC.Post(event: string, data: any?)`

Posts an event to all matching listeners. The event string is matched against all registered patterns, including wildcards. Listeners are called in priority order.

* **event**: The event name to post (e.g., `"system.boot"`, `"network.response"`).
* **data**: Optional data payload to pass to all matching listeners.

```lua
-- Post a simple event
IPC.Post("system.boot")

-- Post an event with data
IPC.Post("network.data", {
    url = "https://api.example.com",
    status = 200,
    body = '{"message": "ok"}'
})

-- Post an event that triggers wildcard listeners
IPC.Post("system.error", { code = 500, message = "Internal Error" })
-- Matches: "system.error", "system.*", "*"
```

**Wildcard matching rules:**

* Exact match: `"system.boot"` matches only `"system.boot"`.
* Wildcard: `"system.*"` matches any event starting with `"system."` (e.g., `"system.boot"`, `"system.error"`, `"system.shutdown"`).
* The `*` character is internally converted to a regex `.*` pattern.

---

### `IPC.Cleanup(taskID: string)`

Removes all listeners that belong to a specific task. Call this when a task is killed to prevent dangling listeners.

* **taskID**: The task identifier (typically the task's PID).

```lua
-- When killing a task, clean up its listeners
local task = KRNL.LaunchTask({ ... })
-- ... later
KRNL.KillTask(task.pid)
IPC.Cleanup(task.pid)
```

> **Note:** KRNL does not automatically call `IPC.Cleanup()` when a task is killed. You should call it manually in your task shutdown logic, or implement it in your OS's task management layer.

---

### `IPC.GetSubscriptionCount(): number`

Returns the total number of active listeners across all events. Useful for debugging and monitoring.

* **Returns**: Number of active subscriptions.

```lua
print("Active IPC subscriptions: " .. IPC.GetSubscriptionCount())
```

---

## Patterns & Best Practices

### Event Naming Convention

Use a dot-separated namespace convention for events to keep them organized and allow wildcard subscriptions:

```
<namespace>.<action>       -- e.g., "system.boot", "user.login"
<namespace>.<target>.<action>  -- e.g., "net.request.complete"
```

Common namespace prefixes:

| Prefix | Usage |
|---|---|
| `system.*` | Kernel lifecycle events (boot, shutdown, error) |
| `user.*` | User-facing events (login, logout, input) |
| `net.*` | Network-related events (request, response, error) |
| `fs.*` | File system events (write, read, delete) |
| `task.*` | Task lifecycle events (create, kill, crash) |

### Task Isolation

Always set the `taskID` option when creating listeners from within a task. This ensures proper cleanup when the task is terminated:

```lua
local function runTask(task)
    IPC.Listen("my.event", function(data)
        -- Handle event
    end, { taskID = task.pid })
end
```

### Priority Ordering

Use priority to control the order in which listeners respond to events. Lower numbers are called first:

```lua
-- Logger runs first (priority 1)
IPC.Listen("system.*", function(data, event)
    log("Event: " .. event)
end, { priority = 1, taskID = "kernel" })

-- UI updater runs second (priority 50)
IPC.Listen("system.boot", function(data)
    updateUI("System Ready")
end, { priority = 50, taskID = uiTask.pid })

-- Analytics runs last (priority 200)
IPC.Listen("system.boot", function(data)
    trackEvent("boot")
end, { priority = 200, taskID = analyticsTask.pid })
```

### One-Time Listeners

Use `once = true` for listeners that should only fire a single time, such as waiting for a specific condition:

```lua
-- Wait for network to be ready, then fetch data
IPC.Listen("net.ready", function()
    NET:Get("https://api.example.com/data", handleResponse)
end, { once = true })
```

---

## Error Handling

If a listener callback throws an error, the error is caught internally and printed to the log. Other listeners for the same event will still execute:

```
![IPC ERROR] <taskID> <error message>
```

This ensures that a single failing listener does not break the entire event dispatch chain.
