
# ⚙️ CPU Driver Reference

The **CPU Driver** is a core hardware abstraction in the KRNL engine. It provides essential timing utilities, performance metrics, and a non-blocking delay system for your applications. 

Unlike standard Lua environments where you might use `wait()` or `os.sleep()`, the Retro Gadgets environment requires a non-yielding approach. The CPU driver handles this elegantly.

---

## 📥 Accessing the Driver

To use the CPU driver in your task or OS shell, retrieve it using the KRNL driver manager:

```lua
local KRNL = require("/KRNL/OS")
local cpu = KRNL.GetDriver("CPU")

if not cpu then
    print("Error: CPU component is missing!")
    return
end
```

---

## ⏱️ Timing & Performance API

### `cpu:GetDeltaTime(): number`
Returns the time (in seconds) elapsed since the last system tick. 
* **Usage:** Crucial for frame-independent calculations (e.g., moving a UI element at a consistent speed regardless of lag).
* **Returns:** `number` (e.g., `0.0166` for a perfect 60 FPS).

```lua
-- Example: Move an object 50 pixels per second safely
local speed = 50
object.x = object.x + (speed * cpu:GetDeltaTime())
```

### `cpu:GetRuntime(): number`
Returns the total time (in seconds) the KRNL engine has been running since boot.
* **Returns:** `number` (Uptime in seconds).

### `cpu:GetTPS(): number`
Calculates the current **Ticks Per Second** (TPS) based on the DeltaTime. The KRNL target is **60 TPS**.
* **Returns:** `number`. If the system is lagging, this number will drop below 60.

### `cpu:GetUsage(): number`
Calculates the simulated CPU load percentage based on the current TPS versus the target TPS.
* **Returns:** `number` between `0` and `100`.
* **Note:** A usage of `100%` means the system is fully loaded and struggling to maintain 60 TPS. A usage of `0%` means perfect performance.

```lua
-- Example: Simple performance monitor
local usage = cpu:GetUsage()
if usage > 80 then
    print("Warning: High CPU Load! (" .. math.floor(usage) .. "%)")
end
```

---

## ⏳ Task Scheduling (Non-Blocking)

### `cpu:Delay(callback: function, time: number?, ...args)`
Schedules a function to be executed after a specified amount of time. This is the **KRNL standard** for delayed execution and entirely replaces standard yielding methods.

It pushes the callback into a registry, and the kernel automatically fires it when the internal `runtime` exceeds the target time.

* **Parameters:**
  * `callback` *(function)*: The function to execute.
  * `time` *(number, optional)*: Delay in seconds. Defaults to `0` (executes on the exact next tick).
  * `...args` *(any)*: Any additional arguments you want to pass to the callback function.

#### Example 1: Basic Delay
```lua
print("Starting task...")
cpu:Delay(function()
    print("This prints 2.5 seconds later!")
end, 2.5)
```

#### Example 2: Passing Arguments safely
Because `cpu:Delay` handles `varargs`, you don't need to wrap functions in anonymous closures just to pass variables.

```lua
local function ShowNotification(title, message)
    print("[" .. title .. "]: " .. message)
end

-- Calls ShowNotification("System", "Update Complete") after 5 seconds
cpu:Delay(ShowNotification, 5, "System", "Update Complete")
```

#### Example 3: Creating a Loop
You can create non-blocking loops by recursively calling `Delay` inside the callback.

```lua
local function BeepLoop()
    speaker:Play()
    cpu:Delay(BeepLoop, 1.0) -- Repeats every 1 second
end
BeepLoop()
```

---

## ⚠️ Internal Methods (Do Not Call Directly)

The following methods are reserved for the **Kernel Scheduler** and should never be called from user applications:
* `cpu.AddDriver()`: Used during boot to register the physical component.
* `cpu.GetDriver()`: Used internally by `KRNL.GetDriver()`.
* `cpu:_update()`: Driven by `KRNL.Update()` to process callbacks and calculate `dt`.
---
