
---

# 💡 LedDriver Reference

The **LedDriver** provides a clean interface for controlling standard LED components. It integrates with the KRNL `Color4` utility and uses a synchronized update loop to manage the visual state of the hardware.

---

## 📥 Accessing the Driver

To control a specific LED (e.g., an status indicator on your gadget):

```lua
local KRNL = require("/KRNL/OS")
local led = KRNL.GetDriver("Led0")

if not led then
    print("LED component not found!")
end
```

---

## 🛠️ Methods

### `led:SetColor(clr: Color4)`
Updates the target color of the LED.
* **Parameter:** `clr` — A `Color4` object (from `KRNL.GetUtility("Color4")`).
* **Note:** The color is applied to the hardware on the next kernel update tick.

### `led:GetColor(): Color4`
Returns the current `Color4` object stored in the driver's metadata.

### `led:SetState(state: boolean)`
Turns the LED on or off.
* **Parameter:** `true` to turn on, `false` to turn off.
* **Behavior:** When `false`, the LED will be dark regardless of the color set.

### `led:GetState(): boolean`
Returns the current logical state of the LED.

---

## 🎨 Integration with Color4

Since the driver expects a `Color4` object, you have full control over RGBA values:

```lua
local Color4 = KRNL.GetUtility("Color4")

-- Setting a bright Green color
led:SetColor(Color4.FromRGB(0, 255, 0))
led:SetState(true)
```

---

## 💡 Practical Examples

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

## ⚠️ Internal Logic

The `LedDriver` follows the **Buffered Property** pattern:
1.  **Logical Update:** When you call `SetColor`, only the `userdata` inside `_driverData` is changed.
2.  **Hardware Sync:** Inside `_update()`, the driver calls `Color4:Convert()` and pushes the result to the physical `instance.Color` and `instance.State`.

> **Performance Tip:** Do not worry about calling `SetState` every frame inside a task; the driver handles the synchronization efficiently during the kernel's update cycle.

---
