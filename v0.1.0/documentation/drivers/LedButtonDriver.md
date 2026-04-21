
#  LedButtonDriver Reference

The **LedButtonDriver** manages `LedButton` components,powerful event-driven system for handling user interactions.

---

## 📥 Accessing the Driver

```lua
local KRNL = require("/KRNL/OS")
local btn = KRNL.GetDriver("LedButton0")

if not btn then
    print("LedButton not found!")
end
```

---

##  Event System

The driver uses `BetterEvents` to notify your application when the button is interacted with.

### `btn.OnPressed`
A signal that fires exactly once when the button is pushed down.
* **Usage:** `btn.OnPressed:Connect(function() ... end)`

### `btn.OnReleased`
A signal that fires exactly once when the button is let go.
* **Usage:** `btn.OnReleased:Connect(function() ... end)`

---

##  Methods

### `btn:IsPressed(): boolean`
Returns the current physical state of the button.
* `true` — Button is currently held down.
* `false` — Button is idle.

### `btn:SetColor(clr: Color4)`
Sets the target color for the button's internal LED.

### `btn:SetLedState(state: boolean)`
Turns the button's backlight on (`true`) or off (`false`).

### `btn:GetColor()` / `btn:GetLedState()`
Returns the current logical values stored in the driver.

---

##  Practical Examples

### 1. Toggle Switch Logic
Making the button light up when pressed and stay lit until pressed again:

```lua
local isLit = false
local Color4 = KRNL.GetUtility("Color4")

btn:SetColor(Color4.FromRGB(0, 255, 255)) -- Cyan

btn.OnPressed:Connect(function()
    isLit = not isLit
    btn:SetLedState(isLit)
    print("System Power: " .. (isLit and "ON" or "OFF"))
end)
```

### 2. Interaction Feedback (Momentary)
The button glows only while it is being held down:

```lua
btn:SetColor(Color4.FromRGB(255, 255, 0)) -- Yellow

btn.OnPressed:Connect(function()
    btn:SetLedState(true)
end)

btn.OnReleased:Connect(function()
    btn:SetLedState(false)
end)
```

---
