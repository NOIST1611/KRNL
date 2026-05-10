# LED Driver

The **LED Driver** wraps a Retro Gadgets `Led` component and provides on/off state control and color management. It uses a deferred update pattern — color and state changes are stored internally and applied to the hardware during the next `_update()` cycle, ensuring consistent timing with the rest of the kernel's driver pipeline.

---

## Overview

LED components in Retro Gadgets are simple indicator lights with configurable color and on/off state. The LED Driver abstracts the hardware into a clean API: set a `Color4` color, toggle the state, and the driver handles the rest on the next tick.

Unlike some other drivers (such as the LCD Driver) that apply changes to hardware immediately, the LED Driver batches its writes. Calls to `SetColor()` and `SetState()` update the internal driver state, and the actual hardware properties (`instance.Color` and `instance.State`) are written during `_update()`. This means all LED changes within a single tick are coalesced into one hardware write, and the visual result always reflects the latest state at the time `KRNL.Update()` processes the driver.

**Key features:**

* **On/off control** — Set and query the LED's power state via `SetState()` / `GetState()`.
* **Color management** — Set and query the LED's color using the `Color4` utility via `SetColor()` / `GetColor()`.
* **Deferred hardware writes** — State and color are stored internally; hardware is updated once per tick in `_update()`.
* **Color4 conversion** — Internal `Color4` values are automatically converted to hardware-compatible format via `Color4:Convert()` during the update cycle.

---

## Accessing the LED Driver

```lua
local KRNL = require("/KRNL/OS")

-- By instance name
local led = KRNL.GetDriver("Led0")
```

---

## Internal Constants & Defaults

| Constant / Default | Value | Description |
|---|---|---|
| `Prefix` | `"[LED DRIVER]:"` | Log message prefix for warnings and info. |
| Default `led_color` | `Color4.FromRGB(0, 0, 0)` | Black (off-color). |
| Default `state` | `false` | LED is off at boot. |

---

## Update Behavior

The LED Driver uses a **deferred update** pattern. Understanding this is important for correct usage.

```
Tick N:
  ├─ led:SetColor(Color4.FromRGB(255, 0, 0))  → stored internally
  ├─ led:SetState(true)                         → stored internally
  ├─ led:SetColor(Color4.FromRGB(0, 255, 0))   → overwrites previous (still internal)
  │
  ▼ KRNL.Update() → _update():
  ├─ Read internal led_color → Convert via Color4:Convert()
  ├─ Read internal state
  ├─ instance.Color = converted_color  → hardware write
  └─ instance.State = state            → hardware write
  
Result: LED shows green (last SetColor wins), ON
```

**Key implications:**

* Calling `SetColor()` multiple times in one tick — only the last value is applied to hardware.
* The hardware always reflects the state at the moment `_update()` runs, not the moment `SetColor()` / `SetState()` was called.
* If `KRNL.Update()` is not called, LED changes will never reach the hardware.

---

## API Reference

### Static Methods

#### `led.AddDriver(instance: Led, name: string, registry: DriverRegistry): LedDriver?`

Static factory method. Creates a new LED driver and registers it in the driver registry. Called internally by the kernel during boot.

* **instance**: The Retro Gadgets `Led` component instance.
* **name**: The driver instance name (e.g., `"Led0"`).
* **registry**: The kernel's driver registry table.
* **Returns**: A new `LedDriver` instance, or `nil` if the component type is invalid.

**Initialization:**

1. Validates `instance.Type == "Led"`.
2. Creates the driver via `setmetatable({}, led)`.
3. Stores the hardware reference in `driver.instance`.
4. Initializes `_driverData` with defaults:
   * `led_color` = `Color4.FromRGB(0, 0, 0)` (black)
   * `state` = `false` (off)
5. Registers the driver in the `registry`.

Note that the default color is black and the default state is off. On the first `_update()` call, the hardware LED will be set to black + off, effectively ensuring a clean initial state regardless of any pre-existing hardware values.

---

#### `led.GetDriver(name: string, registry: DriverRegistry): LedDriver?`

Static lookup method. Retrieves a previously registered LED driver from the registry.

* **name**: The driver instance name.
* **registry**: The kernel's driver registry table.
* **Returns**: The `LedDriver` instance, or `nil` if not found (with a warning logged).

---

### Color Methods

#### `led:SetColor(clr: Color4): ()`

Sets the LED color. The value is stored internally and applied to hardware during the next `_update()` cycle.

* **clr**: A `Color4` value representing the new LED color.

The color is stored as a `Color4` object. During `_update()`, it is converted to hardware format via `Color4:Convert()` before being written to `instance.Color`.

```lua
local Color4 = require("/KRNL/kernel/Utils/Color4")

led:SetColor(Color4.FromRGB(255, 0, 0))     -- Red
led:SetColor(Color4.FromRGB(0, 255, 0))     -- Green
led:SetColor(Color4.FromRGB(0, 0, 255))     -- Blue
led:SetColor(Color4.FromRGB(255, 255, 0))   -- Yellow
led:SetColor(Color4.FromRGB(255, 128, 0))   -- Orange
led:SetColor(Color4.FromRGB(0, 0, 0))       -- Black (off-color)
```

> **Note:** `SetColor()` only changes the color. The LED will not light up unless `SetState(true)` is also called (or was previously set).

---

#### `led:GetColor(): Color4`

Returns the current LED color as stored internally.

* **Returns**: The current `Color4` value. This reflects the last `SetColor()` call, not necessarily the current hardware state (which lags by one tick).

```lua
local color = led:GetColor()
print("LED color:", color:Convert())
```

---

### State Methods

#### `led:SetState(state: boolean): ()`

Sets the LED power state. The value is stored internally and applied to hardware during the next `_update()` cycle.

* **state**: `true` to turn the LED on, `false` to turn it off.

```lua
led:SetState(true)   -- Turn on
led:SetState(false)  -- Turn off
```

---

#### `led:GetState(): boolean`

Returns the current LED power state as stored internally.

* **Returns**: `true` if the LED is on, `false` if off.

```lua
if led:GetState() then
    print("LED is ON")
else
    print("LED is OFF")
end
```

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Invalid component type in `AddDriver` | Logs warning, returns `nil`. |
| Driver not found in `GetDriver` | Logs warning, returns `nil`. |
| Invalid Color4 passed to `SetColor` | No validation — the value is stored as-is. Errors will surface during `Color4:Convert()` in `_update()`. |
| `GetColor` called before any `SetColor` | Returns the default `Color4.FromRGB(0, 0, 0)`. |
| `GetState` called before any `SetState` | Returns the default `false`. |

The LED driver does not validate the `Color4` argument. If `nil` or a non-`Color4` value is passed to `SetColor()`, the `:Convert()` call during `_update()` will throw an error. Always pass valid `Color4` values.

---

## Code Examples

### Blinking with Color Pulse

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local led = KRNL.GetDriver("Led0")
local cpu = KRNL.GetDriver("CPU0")

KRNL.LaunchTask({
    name = "color_pulse",
    UpdateFunction = function(self)
        local t = cpu:GetRuntime()

        -- Smooth pulse using sine wave
        local intensity = (math.sin(t * 4) + 1) / 2  -- 0 to 1
        local r = math.floor(255 * intensity)
        local g = math.floor(100 * (1 - intensity))
        local b = math.floor(255 * (1 - intensity))

        led:SetColor(Color4.FromRGB(r, g, b))
        led:SetState(true)
    end
})
```

### Multi-LED Activity Monitor

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local cpu = KRNL.GetDriver("CPU0")

local leds = {
    status = KRNL.GetDriver("Led0"),
    cpu    = KRNL.GetDriver("Led1"),
}

-- Status LED: solid green = running
leds.status:SetColor(Color4.FromRGB(0, 255, 0))
leds.status:SetState(true)

-- CPU LED: yellow when usage > 50%, red when > 80%
KRNL.LaunchTask({
    name = "led_monitor",
    UpdateFunction = function(self)
        self.data.timer = (self.data.timer or 0) + cpu:GetDeltaTime()

        if self.data.timer >= 0.5 then
            self.data.timer = 0
            local usage = cpu:GetUsage()

            if usage > 80 then
                leds.cpu:SetColor(Color4.FromRGB(255, 0, 0))
            elseif usage > 50 then
                leds.cpu:SetColor(Color4.FromRGB(255, 255, 0))
            else
                leds.cpu:SetColor(Color4.FromRGB(0, 255, 0))
            end
            leds.cpu:SetState(true)
        end
    end,
    Data = {}
})
```

### Heartbeat Pattern (Double-Pulse)

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local led = KRNL.GetDriver("Led0")
local cpu = KRNL.GetDriver("CPU0")

local pattern = {
    { on = true,  delay = 0.15 },
    { on = false, delay = 0.1 },
    { on = true,  delay = 0.15 },
    { on = false, delay = 1.6 },
}

local stepIndex = 1
local stepTimer = 0

KRNL.LaunchTask({
    name = "heartbeat",
    UpdateFunction = function(self)
        local dt = cpu:GetDeltaTime()
        stepTimer = stepTimer + dt

        local step = pattern[stepIndex]
        if stepTimer >= step.delay then
            stepTimer = 0
            stepIndex = (stepIndex % #pattern) + 1

            led:SetColor(Color4.FromRGB(255, 0, 0))
            led:SetState(pattern[stepIndex].on)
        end
    end
})
```

---

## Relationship to Other Components

| Component | Relationship |
|---|---|
| **Color4 Utility** | Provides the `Color4` type used for all color operations. Internal values are converted via `Color4:Convert()` before hardware writes. |
| **CPU Driver** | Provides timing (`GetDeltaTime()`, `GetRuntime()`) and scheduling (`Delay()`) for LED animation patterns. |
| **Keyboard Driver** | Often used to trigger LED state changes in response to user input. |
| **LED Button Driver** | Extended version of the LED driver that combines LED control with button press detection. |
| **Switch Driver** | Can be combined with LED drivers for physical toggle-controlled indicators. |
| **Task Scheduler** | Tasks can manage LED animation patterns in their update loops. |

---
