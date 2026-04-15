
---

# ⚡ SwitchDriver Reference

The **SwitchDriver** manages the `Switch` component. It provides a simple way to read or set the toggle position and features an event-driven mechanism to detect when the switch is flipped.

---

## 📥 Accessing the Driver

```lua
local KRNL = require("/KRNL/OS")
local sw = KRNL.GetDriver("Switch0")

if not sw then
    print("Switch component not found!")
end
```

---

## 🔔 Event System

### `sw.StateChanged`
A signal that fires whenever the switch is toggled (either from `OFF` to `ON` or vice-versa).
* **Usage:** `sw.StateChanged:Connect(function() ... end)`
* **Note:** This event is fired inside the kernel update loop immediately after a change is detected.

---

## 🛠️ Methods

### `sw:GetState(): boolean`
Returns the current logical position of the switch.
* `true` — Switch is in the **ON** position.
* `false` — Switch is in the **OFF** position.

### `sw:SetState(state: boolean)`
Programmatically flips the switch to the desired position.
* **Parameter:** `true` for ON, `false` for OFF.
* **Effect:** This updates the physical component's state immediately.

---

## 💡 Practical Examples

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

## ⚙️ Internal Mechanics

### State Tracking
The driver maintains a cached state in `_driverData.userdata.state`. 

### The Update Loop
During each `_update()` tick, the driver compares the physical `instance.State` with the cached state:
1. If they differ (`instance.State ~= data.state`), it means the user (or another script) flipped the switch.
2. The `StateChanged` event is fired.
3. The cached state is updated to match the physical state.
---
