
---

# LedDriver Reference

The **LedDriver** provides a clean interface for controlling standard LED components.

---

## Accessing the Driver

To control a specific LED (e.g., an status indicator on your gadget):

```lua
local KRNL = require("/KRNL/OS")
local led = KRNL.GetDriver("Led0")

if not led then
    print("LED component not found!")
end
```

---

## Methods

### `led:SetColor(clr: Color4)`
Updates the target color of the LED.
* **Parameter:** `clr` — A `Color4` object (from `KRNL.GetUtility("Color4")`).

### `led:GetColor(): Color4`
Returns the current `Color4` object stored in the driver's metadata.

### `led:SetState(state: boolean)`
Turns the LED on or off.
* **Parameter:** `true` to turn on, `false` to turn off.
* **Behavior:** When `false`, the LED will be dark regardless of the color set.

### `led:GetState(): boolean`
Returns the current logical state of the LED.

---

## Examples

### 1. Status Blinker (Heartbeat)
You can create a task that makes the LED blink to indicate the system is alive:

```lua
KRNL.CreateTask({
    name = "Heartbeat",
    UpdateFunction = function()
        -- Blink every 1 second
        local isEvenSecond = math.floor(cpu:GetRuntime()) % 2 == 0
        led:SetState(isEvenSecond)
    end
})
```

### 2. Smooth Pulse Effect
Using `math.sin` and `Color4`, you can create a pulsing glow:

```lua
KRNL.CreateTask({
    name = "GlowEffect",
    UpdateFunction = function()
        local t = cpu:GetRuntime()
        local intensity = (math.sin(t * 3) + 1) / 2 -- Value between 0 and 1
        
        -- Pulse Red channel
        led:SetColor(Color4.FromRGB(255 * intensity, 0, 0))
        led:SetState(true)
    end
})
```

---
