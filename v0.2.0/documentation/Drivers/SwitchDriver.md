
---

# SwitchDriver Reference

The **SwitchDriver** manages the `Switch` component.

---

## Accessing the Driver

```lua
local KRNL = require("/KRNL/OS")
local sw = KRNL.GetDriver("Switch0")

if not sw then
    print("Switch component not found!")
end
```

---

## Event System

### `sw.StateChanged`
A signal that fires whenever the switch is toggled (either from `OFF` to `ON` or vice-versa).
* **Usage:** `sw.StateChanged:Connect(function() ... end)`

---

## Methods

### `sw:GetState(): boolean`
Returns the current logical position of the switch.
* `true` — Switch is in the **ON** position.
* `false` — Switch is in the **OFF** position.

### `sw:SetState(state: boolean)`
Programmatically flips the switch to the desired position.
* **Parameter:** `true` for ON, `false` for OFF.

---

## Examples

### 1. Basic Toggle Logic
Running a specific function only when the switch is turned on:

```lua
sw.StateChanged:Connect(function()
    local isOn = sw:GetState()
    
    if isOn then
        print("System: ENGAGED")
    else
        print("System: DISENGAGED")
    end
end)
```

### 2. Emergency Kill Switch
Using the switch to instantly stop all tasks or a specific process:

```lua
local function EmergencyMonitor()
    if sw:GetState() == false then
        print("CRITICAL: Kill switch active. Shutting down tasks...")
        -- logic to kill tasks
    end
end

KRNL.CreateTask({
    name = "SafetyMonitor",
    UpdateFunction = EmergencyMonitor
})
```

---
