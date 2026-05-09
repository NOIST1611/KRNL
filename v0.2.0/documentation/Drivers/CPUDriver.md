# CPU Driver

The **CPU Driver** wraps a Retro Gadgets CPU chip and provides timing information, runtime tracking, CPU usage estimation, and a delayed callback scheduling system. It is the foundational driver that all other drivers and the kernel update loop depend on.

---

## Overview

Every Retro Gadgets gadget has at least one CPU chip. The CPU Driver reads hardware timing data each tick and exposes it through a clean API. It also maintains an internal queue of delayed callbacks that fire at specified future times, making it easy to schedule one-shot events without creating full tasks.

**Key features:**

* **Delta time** — Time elapsed since the last tick, sourced directly from the hardware.
* **Runtime tracking** — Cumulative uptime in seconds since kernel boot.
* **TPS monitoring** — Current ticks-per-second, calculated from delta time against the target of 60 TPS.
* **CPU usage estimation** — Percentage-based load indicator derived from TPS deviation.
* **Delayed callbacks** — Schedule functions to fire after a specific delay, with full argument forwarding.

---

## Accessing the CPU Driver

```lua
local KRNL = require("/KRNL/OS")

-- By instance name
local cpu = KRNL.GetDriver("CPU0")

-- The CPU driver is always named "CPU0" for the first CPU,
-- "CPU1" for the second, and so on.
```

---

## Internal Constants

| Constant | Value | Description |
|---|---|---|
| `TARGET_TPS` | `60` | The expected ticks per second. Retro Gadgets targets 60 FPS. |
| `TARGET_DT` | `1 / 60` (~0.0167) | The ideal delta time per tick in seconds. |

These constants are used internally for TPS and usage calculations but are not exported publicly.

---

## API Reference

### `cpu:GetDeltaTime(): number`

Returns the time elapsed since the last tick, in seconds. This value is read directly from the hardware CPU component's `DeltaTime` property each update cycle.

* **Returns**: Delta time in seconds (e.g., `0.0167` at 60 TPS).

The value fluctuates slightly each tick depending on frame timing. On the first tick after boot, or if the hardware reports zero, the value may be `0`.

```lua
local dt = cpu:GetDeltaTime()
print(string.format("Frame time: %.4f s", dt))
```

---

### `cpu:GetRuntime(): number`

Returns the total elapsed time since kernel boot, in seconds. This is a monotonically increasing counter accumulated from delta time each tick.

* **Returns**: Runtime in seconds (e.g., `125.45` means ~2 minutes since boot).

```lua
local uptime = cpu:GetRuntime()
local minutes = math.floor(uptime / 60)
local seconds = math.floor(uptime % 60)
print(string.format("Uptime: %d:%02d", minutes, seconds))
```

---

### `cpu:GetTPS(): number`

Returns the current ticks-per-second, calculated as the reciprocal of delta time. If delta time is zero or negative (e.g., on the first tick), returns the target TPS of `60`.

* **Returns**: Current TPS as a number. At ideal performance, returns `60`. Under load, the value decreases.

**Calculation:**

```
TPS = 1 / dt        (when dt > 0)
TPS = 60            (when dt <= 0)
```

```lua
local tps = cpu:GetTPS()
if tps < 50 then
    print("WARNING: Low TPS: " .. math.floor(tps))
end
```

---

### `cpu:GetUsage(): number`

Returns an estimated CPU usage percentage (0-100), derived from how far the current TPS deviates from the target. The value is clamped to `[0, 100]` and rounded to the nearest integer.

* **Returns**: CPU usage as an integer percentage (0-100).

**Calculation:**

```
if dt <= 0 → return 0

current_tps = 1 / dt
min_tps     = 20
load        = ((TARGET_TPS - current_tps) / (TARGET_TPS - min_tps)) * 100
usage       = clamp(round(load), 0, 100)
```

The formula maps the TPS range `[20, 60]` to a usage range of `[100%, 0%]`:

| TPS | Usage |
|---|---|
| 60 | 0% |
| 50 | 25% |
| 40 | 50% |
| 30 | 75% |
| 20 | 100% |
| < 20 | 100% (clamped) |

> **Note:** This is a heuristic estimation based on frame timing, not a true hardware CPU usage metric. For real CPU metrics, use the `RealityDriver.GetCPUUsage()` method if a Reality Chip is available.

```lua
local usage = cpu:GetUsage()
print("CPU Usage: " .. usage .. "%")

if usage > 80 then
    print("WARNING: High CPU load!")
end
```

---

### `cpu:Delay(callback: (...any) -> (), time: number?, ...: any): ()`

Schedules a callback to be invoked after a specified delay. The callback fires once and is then automatically removed from the queue. Multiple arguments can be passed after `time` and will be forwarded to the callback.

* **callback**: The function to call when the delay expires. Signature: `(...any) -> ()`.
* **time**: *(Optional)* Delay in seconds. If `nil` or `0`, the callback fires on the next tick. Defaults to `0`.
* **`...`**: *(Optional)* Additional arguments to pass to the callback when it fires.

**How it works internally:**

1. The delay is converted to an absolute target time: `target_time = current_runtime + time`.
2. The callback entry (including packed arguments) is added to the internal `delayed_callbacks` queue.
3. During each `_update()` cycle, the driver iterates the queue in reverse order.
4. Any callback whose target time has been reached is executed via `pcall`.
5. If the callback throws an error, it is caught and logged — other callbacks are not affected.
6. After execution, the callback is removed from the queue.

> **Important:** Callbacks are processed during `KRNL.Update()`, which must be called in the global `update()` function. If `KRNL.Update()` is not called, delayed callbacks will never fire.

```lua
-- Fire after 2 seconds
cpu:Delay(function()
    print("2 seconds have passed!")
end, 2.0)

-- Fire immediately (next tick)
cpu:Delay(function()
    print("Next tick!")
end)

-- With arguments
cpu:Delay(function(name, score)
    print(name .. " scored " .. score)
end, 1.5, "Player1", 100)

-- Chain multiple delays
cpu:Delay(function()
    print("Step 1")
    cpu:Delay(function()
        print("Step 2 (0.5s after Step 1)")
    end, 0.5)
end, 1.0)
-- Output after ~1.5s: "Step 1", then "Step 2 (0.5s after Step 1)"
```

---

## Internal Update Loop

The `_update()` method is called automatically by `KRNL.Update()` every tick. It performs the following:

1. **Read delta time** — Stores `instance.DeltaTime` into `userdata.dt`.
2. **Accumulate runtime** — Adds delta time to `userdata.runtime`.
3. **Process delayed callbacks** — Iterates the callback queue in reverse order. For each callback whose target time has been reached:
    * Executes the callback with its saved arguments via `pcall`.
    * Logs a warning if the callback throws an error.
    * Removes the callback from the queue.

The reverse iteration ensures safe removal of items during traversal without index shifting issues.

```
_update() flow:
  ┌─ Read DeltaTime → store as dt
  ├─ runtime += dt
  └─ For each callback (reverse order):
     ├─ if runtime >= callback.time
     │  ├─ pcall(callback.fn, unpack(callback.args))
     │  ├─ Log warning on error
     │  └─ Remove from queue
     └─ else: skip (not yet time)
```

---

## Error Handling

Delayed callbacks are executed inside `pcall`. If a callback throws an error, the following happens:

1. The error is caught and logged: `[CPU DRIVER]: Callback error: <error message>`.
2. The callback is still removed from the queue (it does not retry).
3. All other pending callbacks continue to execute normally.

```lua
-- This callback will throw an error, but won't crash the kernel
cpu:Delay(function()
    error("Something went wrong!")
end, 1.0)
-- Log output: [CPU DRIVER]: Callback error: .../file.lua:2: Something went wrong!
```

---

## Code Examples

### FPS Counter Task

```lua
local KRNL = require("/KRNL/OS")
local cpu = KRNL.GetDriver("CPU0")

local fpsTask = KRNL.LaunchTask({
    name = "fps_counter",
    UpdateFunction = function(self)
        self.data.frames = (self.data.frames or 0) + 1
        self.data.elapsed = (self.data.elapsed or 0) + cpu:GetDeltaTime()

        -- Update display every second
        if self.data.elapsed >= 1.0 then
            local tps = self.data.frames / self.data.elapsed
            print(string.format("FPS: %.1f | Usage: %d%%", tps, cpu:GetUsage()))
            self.data.frames = 0
            self.data.elapsed = 0
        end
    end,
    Data = { frames = 0, elapsed = 0 }
})
```

### Scheduled Repeating Event

Since `Delay` is one-shot, create a repeating pattern by re-scheduling inside the callback:

```lua
local KRNL = require("/KRNL/OS")
local cpu = KRNL.GetDriver("CPU0")

local function everySecond(counter)
    counter.value = (counter.value or 0) + 1
    print("Tick #" .. counter.value)

    -- Re-schedule for next second
    cpu:Delay(function()
        everySecond(counter)
    end, 1.0)
end

-- Start the repeating timer
cpu:Delay(function()
    everySecond({})
end, 1.0)
```

### Runtime-Based Logic

```lua
local KRNL = require("/KRNL/OS")
local cpu = KRNL.GetDriver("CPU0")

local BOOT_SCREEN_DURATION = 3.0

local bootTask = KRNL.LaunchTask({
    name = "boot_screen",
    UpdateFunction = function(self)
        local elapsed = cpu:GetRuntime()

        if elapsed < BOOT_SCREEN_DURATION then
            -- Show boot animation
            local progress = elapsed / BOOT_SCREEN_DURATION
            print("Booting... " .. math.floor(progress * 100) .. "%")
        else
            -- Boot complete
            print("KRNL Ready!")
            self:SetState("idle")
        end
    end,
    Data = {}
})
```

### Performance Monitoring Dashboard

```lua
local KRNL = require("/KRNL/OS")
local cpu = KRNL.GetDriver("CPU0")
local lcd = KRNL.GetDriver("Lcd0")

KRNL.LaunchTask({
    name = "perf_monitor",
    UpdateFunction = function(self)
        self.data.timer = (self.data.timer or 0) + cpu:GetDeltaTime()

        if self.data.timer >= 0.5 then
            self.data.timer = 0
            
            local usage = cpu:GetUsage()
            local runtime = cpu:GetRuntime()

            lcd:Clear()
            lcd:PrintLine(1, string.format("CPU: %d%%", usage))
            lcd:PrintLine(2, string.format("Up: %.0fs", runtime))
        end
    end,
    Data = { timer = 0 }
})
```

---

## Relationship to Other Components

| Component | Relationship |
|---|---|
| **Task Scheduler** | Uses `GetDeltaTime()` internally for timing. Tasks run once per `_update()` cycle. |
| **NET Module** | Uses `GetRuntime()` for cache timestamps, timeout calculations, and elapsed time tracking. |
| **All Drivers** | Each driver's `_update()` is called once per tick within the same `KRNL.Update()` cycle. |
| **Reality Driver** | Provides real CPU usage (`GetCPUUsage()`) as an alternative to the driver's heuristic estimation. |
| **Delayed Callbacks** | Managed internally by the CPU driver's `_update()` — no external coordination needed. |

---

## Limitations

* **Heuristic usage** — `GetUsage()` is a frame-time-based estimation, not a true hardware metric. It assumes a linear relationship between TPS drop and CPU load, which may not reflect actual computation cost.
* **No precision timing** — Delayed callbacks are checked once per tick (~60Hz). Minimum practical delay granularity is ~16.7ms. Callbacks scheduled for very short delays may fire one tick late.
* **Callback ordering** — When multiple callbacks are due in the same tick, they execute in reverse insertion order (last scheduled fires first).
* **No cancellation** — Once scheduled via `Delay()`, a callback cannot be individually cancelled. Design callbacks to be idempotent if this is a concern.
