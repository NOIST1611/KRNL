# Execution Handler

The **Execution Handler** is KRNL's pluggable file execution system. It allows developers to register custom handlers for any file extension, enabling the kernel to execute different file formats (scripts, configs, binaries, etc.) through a unified interface.

---

## Overview

The Execution Handler acts as a registry of format-specific executors. When a file is executed via `KRNL.Execute()` or `vfs:Execute()`, the handler looks up the file extension and delegates to the appropriate registered handler.

**Key concepts:**

* **Format Registration** — Register a handler function for any file extension (`.lua`, `.kss`, `.txt`, etc.).
* **Execution Modes** — Each format can be registered as either `"sync"` (inline execution) or `"async"` (creates a background task).
* **Task Configuration** — Async handlers can provide default task configs that are merged with file-specific configs.
* **Format Configuration** — Each format can have custom configuration data passed to its handler.

---

## Accessing the Execution Handler

```lua
local KRNL = require("/KRNL/OS")
local Exec = KRNL.GetExecutionHandler()
-- or
local Exec = KRNL.GetUtility("ExecutionHandler")
```

---

## Core API Reference

### `ExecutionHandler.RegisterFormat(extension: string, handler: function, mode: "sync" | "async", config: table?, task_config: TaskConfig?)`

Registers a new file format handler. This is the primary method for extending the kernel's file execution capabilities.

* **extension**: The file extension to register, including the dot (e.g., `".lua"`, `".kss"`). Case-insensitive (stored/looked up in lowercase).
* **handler**: The handler function with signature `(content: string, path: string, config: table) -> any`.
    * For `"sync"` mode: the return value is passed back as the result.
    * For `"async"` mode: must return a `TaskConfig` table (or `nil` on failure).
* **mode**: Execution mode.
    * `"sync"` — Executed inline in the calling context. No task is created.
    * `"async"` — The handler returns a TaskConfig, and a new task is launched.
* **config**: *(Optional)* Custom configuration data passed to the handler on every invocation.
* **task_config**: *(Optional)* Default `TaskConfig` values merged into the async task. The `Data` table from `task_config` and the handler's return value are merged (handler values take precedence).

```lua
-- Register a sync handler for .cfg files
Exec.RegisterFormat(".cfg", function(content, path, config)
    print("Loading config from: " .. path)
    -- Parse and apply config
    local settings = parseConfig(content)
    return settings
end, "sync")

-- Register an async handler for .lua scripts
Exec.RegisterFormat(".lua", function(content, path, config)
    local fn, err = loadstring(content)
    if not fn then
        return nil
    end
    return {
        name = path,
        UpdateFunction = fn(),
        Data = { sourcePath = path }
    }
end, "async", { sandbox = true }, {
    Data = { maxTicks = 1000 }
})
```

---

### `ExecutionHandler.GetHandler(extension: string): function?`

Returns the handler function registered for the given extension.

* **extension**: File extension (e.g., `".lua"`).
* **Returns**: Handler function or `nil` if not registered.

```lua
local handler = Exec.GetHandler(".lua")
if handler then
    print("Lua handler is registered")
end
```

---

### `ExecutionHandler.GetMode(extension: string): string?`

Returns the execution mode for the given extension.

* **extension**: File extension.
* **Returns**: `"sync"`, `"async"`, or `nil`.

```lua
local mode = Exec.GetMode(".lua")
-- "async"
```

---

### `ExecutionHandler.GetConfig(extension: string): table?`

Returns the custom configuration data for the given extension.

* **extension**: File extension.
* **Returns**: Configuration table or `nil`.

---

### `ExecutionHandler.GetTaskConfig(extension: string): table?`

Returns the default task configuration for async formats.

* **extension**: File extension.
* **Returns**: Default TaskConfig table or `nil`.

---

### `ExecutionHandler.HasFormat(extension: string): boolean`

Checks whether a handler is registered for the given extension.

* **extension**: File extension.
* **Returns**: `true` if registered, `false` otherwise.

```lua
if Exec.HasFormat(".lua") then
    print("Lua execution is supported")
end
```

---

### `ExecutionHandler.GetFormats(): { string }`

Returns a list of all registered formats and their modes.

* **Returns**: Array of strings in format `"<extension> [<mode>]"`.

```lua
local formats = Exec.GetFormats()
for _, f in ipairs(formats) do
    print(f)  -- e.g., ".lua [async]", ".kss [sync]"
end
```

---

### `ExecutionHandler.Execute(path: string, content: string): (boolean, string?)`

Directly executes content using the registered handler for the file extension extracted from the path. This is called internally by `vfs:Execute()`.

* **path**: File path (used to extract the extension).
* **content**: The file content to execute.
* **Returns**: `success` (boolean), `errorMessage` (string or nil).

```lua
local ok, err = Exec.Execute("/bin/script.lua", fileContent)
if not ok then
    print("Execution failed: " .. err)
end
```

---

## Execution Flow

When `KRNL.Execute(vfs, path, killOnFinish)` is called, the following happens:

```
1. Read file content from VFS
2. Extract file extension
3. Lookup Execution Handler for extension
4. ┌─ Mode is "async"?
5. │  ├─ Call handler(content, path, config) → TaskConfig
5. │  ├─ Merge base_task_config with file_task_config
5. │  ├─ KRNL.LaunchTask(merged_config) → Task
5. │  └─ Return (true, nil, task)
5. └─ Mode is "sync" or no handler?
6.    ├─ vfs:Execute(path) → inline execution
6.    └─ Return (ok, err, nil)
```

### Async Task Config Merging

For async handlers, the final TaskConfig is constructed by merging two sources:

1. **Base Task Config** (from `RegisterFormat`'s `task_config` parameter) — provides default values.
2. **File Task Config** (returned by the handler function) — provides file-specific values.

The merge follows these rules:
* Scalar values (name, UpdateFunction) from the handler take precedence.
* The `Data` tables are merged: base `Data` is copied first, then handler `Data` overwrites duplicate keys.

```lua
-- Base task_config (from RegisterFormat)
{ Data = { maxTicks = 1000, sandbox = false } }

-- Handler return value
{ name = "my_app", UpdateFunction = myFn, Data = { maxTicks = 500 } }

-- Final merged config
{ name = "my_app", UpdateFunction = myFn, Data = { maxTicks = 500, sandbox = false } }
```

---

## Example: Registering a Custom Format

```lua
local KRNL = require("/KRNL/OS")
local Exec = KRNL.GetExecutionHandler()

-- Register a .json handler that validates and prints JSON
Exec.RegisterFormat(".json", function(content, path, config)
    print("Parsing JSON: " .. path)
    local ok, data = KRNL.GetPrimaryNET().Decode(content)
    if ok then
        print("Valid JSON with " .. #data .. " entries")
    else
        print("Invalid JSON: " .. tostring(data))
    end
end, "sync")

-- Register a .loop handler that creates a repeating task
Exec.RegisterFormat(".loop", function(content, path, config)
    local lines = {}
    for line in content:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local index = 1
    return {
        name = "loop:" .. path,
        UpdateFunction = function(self)
            if index <= #lines then
                print(lines[index])
                index += 1
            else
                index = 1  -- Loop
            end
        end,
        Data = { interval = config.interval or 1 }
    }
end, "async", { interval = 1 })
```
