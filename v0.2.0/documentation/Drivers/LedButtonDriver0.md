# LED Button Driver

The **LED Button Driver** wraps a Retro Gadgets `LedButton` component and combines LED color/state control with physical button press detection and event signals. It merges the output capabilities of an LED with the input capabilities of a momentary push button, using the same deferred update pattern as the LED Driver for visual state while providing reactive signals for button interactions.

---

## Overview

The `LedButton` component in Retro Gadgets is a combined hardware element — a button with an integrated LED indicator. Pressing the button triggers hardware state changes, and the LED can be programmed to reflect status visually. The LED Button Driver unifies both aspects under a single API: you can set the LED color and state, detect button presses, and react to press/release events through signals.

Like the LED Driver, visual changes (color and state) are deferred to the `_update()` cycle. However, button state queries (`IsPressed()`) read directly from the hardware for immediate response, while press/release signals (`OnPressed`, `OnReleased`) fire during `_update()` based on hardware edge detection.

**Key features:**

* **LED color control** — Set and query the LED color using `Color4` via `SetColor()` / `GetColor()`.
* **LED state control** — Set and query the LED on/off state via `SetLedState()` / `GetLedState()`.
* **Button press detection** — Query the current button state directly via `IsPressed()`.
* **Event signals** — `OnPressed` fires when the button is pressed down, `OnReleased` fires when it is released.
* **Deferred visual updates** — LED color and state are applied to hardware once per tick in `_update()`.
* **Edge-triggered signals** — Press and release signals fire exactly once per state transition, not continuously while held.

---

## Accessing the LED Button Driver

```lua
local KRNL = require("/KRNL/OS")

-- By instance name
local btn = KRNL.GetDriver("LedButton0")

-- LED button drivers are named based on the component instance name,
-- e.g. "LedButton0", "LedButton1", "BtnA", "BtnB", etc.
```

---

## Internal Constants & Defaults

| Constant / Default | Value | Description |
|---|---|---|
| `Prefix` | `"[LEDBUTTON DRIVER]:"` | Log message prefix for warnings and info. |
| Default `led_color` | `Color4.FromRGB(0, 0, 0)` | Black (off-color). |
| Default `led_state` | `false` | LED is off at boot. |

---

## Update Behavior

The LED Button Driver has a mixed update model: visual state is deferred, but button queries are immediate. Understanding this distinction is critical for correct usage.

```
Tick N — Application code:
  ├─ btn:SetColor(Color4.FromRGB(0, 255, 0))   → stored internally (deferred)
  ├─ btn:SetLedState(true)                        → stored internally (deferred)
  ├─ if btn:IsPressed() then ... end               → reads hardware DIRECTLY (immediate)
  │
  ▼ KRNL.Update() → _update():
  ├─ Convert led_color via Color4:Convert()
  ├─ instance.LedColor = converted_color          → hardware write (LED)
  ├─ instance.LedState = led_state                → hardware write (LED)
  ├─ if instance.ButtonDown then
  │    └─ OnPressed:Fire()                        → signal (edge: was not pressed, now pressed)
  ├─ elseif instance.ButtonUp then
  │    └─ OnReleased:Fire()                       → signal (edge: was pressed, now released)
  └─ (else: no state change, no signals)
```

**Key implications:**

* `IsPressed()` reflects the **current** hardware state at the time of the call, within the same tick.
* `OnPressed` / `OnReleased` signals fire **during** `_update()`, which means they fire after all application code for the current tick has already executed.
* LED color and state changes are not visible on hardware until `_update()` runs.
* If `KRNL.Update()` is not called, LED changes and signals will never be processed.

---

## Event Signals

The LED Button Driver exposes two signals created via `BetterEvents`:

| Signal | Fired When | Arguments |
|---|---|---|
| `OnPressed` | The button transitions from not-pressed to pressed (`instance.ButtonDown == true`). | None. |
| `OnReleased` | The button transitions from pressed to not-pressed (`instance.ButtonUp == true`). | None. |

Signal names follow the pattern `{instance_name}_onpressed` and `{instance_name}_onreleased` internally.

**Edge detection:** Signals fire once per state transition, not continuously. Holding the button down fires `OnPressed` once on the first tick and nothing on subsequent ticks until the button is released.

```lua
btn.OnPressed:Connect(function()
    print("Button pressed!")
end)

btn.OnReleased:Connect(function()
    print("Button released!")
end)
```

---

## API Reference

### Static Methods

#### `ledButton.AddDriver(instance: LedButton, name: string, registry: DriverRegistry): LedButtonDriver?`

Static factory method. Creates a new LED Button driver and registers it in the driver registry. Called internally by the kernel during boot.

* **instance**: The Retro Gadgets `LedButton` component instance.
* **name**: The driver instance name (e.g., `"LedButton0"`).
* **registry**: The kernel's driver registry table.
* **Returns**: A new `LedButtonDriver` instance, or `nil` if the component type is invalid.

**Initialization:**

1. Validates `instance.Type == "LedButton"`.
2. Creates the driver via `setmetatable({}, ledButton)`.
3. Stores the hardware reference in `driver.instance`.
4. Initializes `_driverData` with defaults:
   * `led_color` = `Color4.FromRGB(0, 0, 0)` (black)
   * `led_state` = `false` (off)
5. Creates two signals via `BetterEvents.new()`:
   * `OnPressed`, `OnReleased`
6. Registers the driver in the `registry`.

---

#### `ledButton.GetDriver(name: string, registry: DriverRegistry): LedButtonDriver?`

Static lookup method. Retrieves a previously registered LED Button driver from the registry.

* **name**: The driver instance name.
* **registry**: The kernel's driver registry table.
* **Returns**: The `LedButtonDriver` instance, or `nil` if not found (with a warning logged).

---

### LED Color Methods

#### `btn:SetColor(clr: Color4): ()`

Sets the LED color. The value is stored internally and applied to hardware during the next `_update()` cycle via `instance.LedColor`.

* **clr**: A `Color4` value representing the new LED color.

```lua
local Color4 = require("/KRNL/kernel/Utils/Color4")

btn:SetColor(Color4.FromRGB(255, 0, 0))   -- Red
btn:SetColor(Color4.FromRGB(0, 255, 0))   -- Green
```

---

#### `btn:GetColor(): Color4`

Returns the current LED color as stored internally.

* **Returns**: The current `Color4` value.

```lua
local clr = btn:GetColor()
```

---

### LED State Methods

#### `btn:SetLedState(state: boolean): ()`

Sets the LED power state. Stored internally and applied during `_update()` via `instance.LedState`.

* **state**: `true` to turn the LED on, `false` to turn it off.

> **Note:** The method is named `SetLedState` (not `SetState`) to avoid confusion with button state. The LED state and button state are independent — you can have the LED on while the button is not pressed, and vice versa.

```lua
btn:SetLedState(true)   -- Turn LED on
btn:SetLedState(false)  -- Turn LED off
```

---

#### `btn:GetLedState(): boolean`

Returns the current LED power state as stored internally.

* **Returns**: `true` if the LED is on, `false` if off.

```lua
if btn:GetLedState() then
    print("LED is ON")
end
```

---

### Button Input Methods

#### `btn:IsPressed(): boolean`

Returns whether the button is currently being pressed. This reads directly from the hardware (`instance.ButtonState`), bypassing the deferred update cycle.

* **Returns**: `true` if the button is currently held down, `false` otherwise.

Because `IsPressed()` reads the hardware directly, it reflects the current physical state at the time of the call. This makes it suitable for polling in task update loops for continuous actions (hold-to-move, hold-to-charge, etc.).

```lua
-- Polling in a task update loop
KRNL.LaunchTask({
    name = "hold_action",
    UpdateFunction = function(self)
        if btn:IsPressed() then
            self.data.charge = (self.data.charge or 0) + cpu:GetDeltaTime()
            print("Charging: " .. self.data.charge)
        else
            self.data.charge = 0
        end
    end
})
```

> **Difference from signals:** `IsPressed()` returns the current level (pressed or not). Signals (`OnPressed` / `OnReleased`) fire on transitions (press started, press ended). Use `IsPressed()` for continuous/polling behavior and signals for event-driven behavior.

---

## Internal Update Loop

The `_update()` method is called automatically by `KRNL.Update()` every tick. It performs two distinct operations:

```
_update() flow:
  ├─ 1. Apply LED state to hardware:
  │  ├─ instance.LedColor = led_color:Convert()
  │  └─ instance.LedState = led_state
  │
  └─ 2. Process button state transitions:
     ├─ if instance.ButtonDown  → OnPressed:Fire()
     └─ if instance.ButtonUp    → OnReleased:Fire()
```

**Signal edge detection:** The hardware properties `ButtonDown` and `ButtonUp` are edge-triggered — `ButtonDown` is `true` only on the tick the button transitions from up to down, and `ButtonUp` is `true` only on the tick it transitions from down to up. This means signals fire exactly once per press/release cycle without any additional debouncing logic in the driver.

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Invalid component type in `AddDriver` | Logs warning, returns `nil`. |
| Driver not found in `GetDriver` | Logs warning, returns `nil`. |
| Invalid Color4 passed to `SetColor` | No validation — errors will surface during `Color4:Convert()` in `_update()`. |
| `GetColor` before `SetColor` | Returns default `Color4.FromRGB(0, 0, 0)`. |
| `GetLedState` before `SetLedState` | Returns default `false`. |
| `IsPressed()` when button untouched | Returns `false`. |

---

## Code Examples

### Basic Press/Release Handling

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local btn = KRNL.GetDriver("LedButton0")

btn.OnPressed:Connect(function()
    btn:SetColor(Color4.FromRGB(255, 255, 0))  -- Yellow when pressed
    btn:SetLedState(true)
    print("Button pressed!")
end)

btn.OnReleased:Connect(function()
    btn:SetColor(Color4.FromRGB(0, 100, 0))   -- Dim green when released
    btn:SetLedState(true)
    print("Button released!")
end)

-- Set initial state
btn:SetColor(Color4.FromRGB(0, 100, 0))
btn:SetLedState(true)
```

### Toggle LED on Press

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local btn = KRNL.GetDriver("LedButton0")

local isOn = false

btn.OnPressed:Connect(function()
    isOn = not isOn

    if isOn then
        btn:SetColor(Color4.FromRGB(0, 255, 0))
        btn:SetLedState(true)
        print("LED: ON")
    else
        btn:SetColor(Color4.FromRGB(0, 0, 0))
        btn:SetLedState(false)
        print("LED: OFF")
    end
end)
```

### Cycle Through Colors

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local btn = KRNL.GetDriver("LedButton0")

local colors = {
    Color4.FromRGB(255, 0, 0),     -- Red
    Color4.FromRGB(255, 128, 0),   -- Orange
    Color4.FromRGB(255, 255, 0),   -- Yellow
    Color4.FromRGB(0, 255, 0),     -- Green
    Color4.FromRGB(0, 0, 255),     -- Blue
    Color4.FromRGB(128, 0, 255),   -- Purple
}

local colorIndex = 1

btn.OnPressed:Connect(function()
    colorIndex = (colorIndex % #colors) + 1
    btn:SetColor(colors[colorIndex])
    btn:SetLedState(true)
end)
```

### Hold-to-Charge with Visual Feedback

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local btn = KRNL.GetDriver("LedButton0")
local cpu = KRNL.GetDriver("CPU0")

local maxCharge = 3.0
local wasCharging = false

KRNL.LaunchTask({
    name = "charge_button",
    UpdateFunction = function(self)
        local pressed = btn:IsPressed()

        if pressed then
            self.data.charge = (self.data.charge or 0) + cpu:GetDeltaTime()
            local progress = math.min(self.data.charge / maxCharge, 1.0)

            -- Interpolate color from red to green
            local r = math.floor(255 * (1 - progress))
            local g = math.floor(255 * progress)
            btn:SetColor(Color4.FromRGB(r, g, 0))
            btn:SetLedState(true)

            if progress >= 1.0 and not wasCharging then
                print("FULLY CHARGED!")
                wasCharging = true
            end
        else
            if self.data.charge and self.data.charge > 0.1 then
                print(string.format("Released at %.0f%%", (self.data.charge / maxCharge) * 100))
            end
            self.data.charge = 0
            wasCharging = false
            btn:SetColor(Color4.FromRGB(0, 0, 0))
            btn:SetLedState(false)
        end
    end
})
```

### Confirmation Dialog (Press and Hold)

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local btn = KRNL.GetDriver("LedButton0")
local cpu = KRNL.GetDriver("CPU0")

local CONFIRM_TIME = 2.0  -- seconds to hold

local function waitForConfirm(callback)
    local startTime = nil

    btn.OnPressed:Connect(function()
        startTime = cpu:GetRuntime()
    end)

    btn.OnReleased:Connect(function()
        if startTime then
            local held = cpu:GetRuntime() - startTime
            if held >= CONFIRM_TIME then
                -- Confirmed: long press
                btn:SetColor(Color4.FromRGB(0, 255, 0))
                btn:SetLedState(true)
                print("Confirmed!")
                callback(true)
            else
                -- Cancelled: short press
                btn:SetColor(Color4.FromRGB(255, 0, 0))
                btn:SetLedState(true)
                print("Cancelled!")
                callback(false)
            end
            startTime = nil

            cpu:Delay(function()
                btn:SetColor(Color4.FromRGB(0, 0, 0))
                btn:SetLedState(false)
            end, 0.5)
        end
    end)

    -- Visual feedback while holding
    KRNL.LaunchTask({
        name = "confirm_visual",
        UpdateFunction = function(self)
            if startTime then
                local elapsed = cpu:GetRuntime() - startTime
                local progress = math.min(elapsed / CONFIRM_TIME, 1.0)

                -- Pulse brightness as feedback
                local flash = math.floor((math.sin(elapsed * 10) + 1) * 127)
                btn:SetColor(Color4.FromRGB(flash, flash, 0))
                btn:SetLedState(true)
            end
        end
    })
end

-- Usage
waitForConfirm(function(confirmed)
    if confirmed then
        print("Action confirmed by long press!")
    end
end)
```

---

## Relationship to Other Components

| Component | Relationship |
|---|---|
| **LED Driver** | Simpler sibling — provides only LED control without button input. Use `LedDriver` for status indicators that don't need interaction. |
| **Color4 Utility** | Provides the `Color4` type for all color operations. Values are converted via `Color4:Convert()` before hardware writes. |
| **CPU Driver** | Provides timing for hold-to-charge patterns, delay for visual feedback, and runtime tracking. |
| **Switch Driver** | Alternative input component — provides toggle state instead of momentary press. Use switches for on/off settings and LED buttons for action triggers. |
| **BetterEvents** | Provides the `Signal` system used by `OnPressed` and `OnReleased`. |
| **Task Scheduler** | Tasks can poll `IsPressed()` in update loops for continuous hold-detection behavior. |

---

## LED Button vs Related Drivers

| Feature | LED Button Driver | LED Driver | Switch Driver |
|---|---|---|---|
| Component | `LedButton` | `Led` | `Switch` |
| LED color | Yes | Yes | No |
| LED state | Yes | Yes | No |
| Button press | Yes (`IsPressed`) | No | No |
| Toggle state | No | No | Yes (`GetState`, `StateChanged`) |
| Press signals | `OnPressed`, `OnReleased` | None | None |
| State signal | None | None | `StateChanged` |
| Input type | Momentary | None | Toggle |
| Typical use | Action buttons, confirm dialogs | Status indicators | Settings toggles |

---
