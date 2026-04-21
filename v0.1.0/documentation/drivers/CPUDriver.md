
# CPU Driver Reference

The **CPU Driver** is a core hardware abstraction in the KRNL. It provides essential timing utilities, performance metrics, and a non-blocking delay system for applications. 

---

## Accessing the Driver

To use the CPU driver in your task or OS shell, retrieve it using the KRNL syscall:

```lua
local KRNL = require("/KRNL/OS")
local cpu = KRNL.GetDriver("CPU0")

if not cpu then
    print("Error: CPU0 component is missing!")
    return
end
```

---

##  Timing & Performance API

### `cpu:GetDeltaTime(): number`
Returns the time (in seconds) elapsed since the last system tick. 
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

```lua
-- Example: Simple performance monitor
local usage = cpu:GetUsage()
if usage > 80 then
    print("Warning: High CPU Load! (" .. math.floor(usage) .. "%)")
end
```

---

##  Task Scheduling

### `cpu:Delay(callback: function, time: number?, ...args)`
Schedules a function to be executed after a specified amount of time.

* **Parameters:**
  * `callback` *(function)*: The function to execute.
  * `time` *(number, optional)*: Delay in seconds. Defaults to `0` (executes on the exact next tick).
  * `...args` *(any)*: Any additional arguments you want to pass to the callback function.

#### Example 1: Basic usage

```lua
print("Starting task...")
cpu:Delay(function()
    print("This prints 2.5 seconds later!")
end, 2.5)
```

#### Example 2: Creating a Loop

```lua
local function BeepLoop()
    speaker:Play()
    cpu:Delay(BeepLoop, 1.0) -- Repeats every 1 second
end
BeepLoop()
```

---
