
## Overview

SliderDriver is a minimal driver for the Retro Gadgets `Slider` component. It provides read and write access to the slider's value, detects when the value changes between ticks

---

## Architecture

### Value Caching

The driver maintains an internal copy of the slider value (`userdata.value`). On each `update()` tick, the cached value is compared against the live hardware value (`instance.Value`). If they differ, the `ValueChanged` event is fired and the cache is updated. This means the event fires at most once per tick, even if the hardware value changes multiple times within a single frame.

### Event Model

Unlike some other drivers that use edge-triggered logic with complex state machines, SliderDriver uses a simple **dirty-check** pattern: any difference between the cached and live value triggers the event. There is no distinction between "increasing" and "decreasing" — the consumer can call `:GetValue()` inside the handler to determine the new value and compute the delta if needed.

---

## API Reference

### `Driver:SetValue(value: number)`

Sets the hardware slider value directly.

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | `number` | The value to set on the slider component |

This writes immediately to `instance.Value`. Note that the change will not trigger `ValueChanged` until the next `_update()` tick, when the internal cache is compared against the new hardware value. This is the expected behavior — programmatic changes are detected the same way as physical user interaction.

> **Important:** This method sets the value on the physical slider component, which may visually move the slider in the game. Use this when you need to sync the slider position from code rather than reading user input.

### `Driver:GetValue() -> number`

Returns the cached slider value from the last `_update()` tick.

**Returns:** `number` — the last known slider value.

> **Note:** This returns the **cached** value (`userdata.value`), not the live hardware value. There may be a delay of up to one tick between the physical slider moving and this method reflecting the change. For the most up-to-date value, read `instance.Value` directly.

### `Driver:IsMoving() -> boolean`

Checks whether the slider is currently being interacted with by the user.

**Returns:** `boolean` — `true` if the slider is physically being moved, `false` otherwise.

This reads the `instance.IsMoving` property directly from the hardware component and is not affected by the caching system.

---

## Event System

### `Driver.ValueChanged`

Fired once per tick when the slider value differs from the cached value.

**Payload:** none (no arguments passed to handlers).

To get the current value inside the handler, call `:GetValue()`:

```lua
driver.ValueChanged:Connect(function()
    local v = driver:GetValue()
    print(string.format("Slider changed to: %.2f", v))
end)
```

**Firing conditions:**
- The user physically moves the slider.
- The value is changed programmatically via `:SetValue()` and one `_update()` tick has passed.
- The value is changed externally by another script modifying the same slider component.

**Non-firing conditions:**
- The slider value has not changed since the last tick.
- The slider is not interacted with.

---

## Error Handling

| Situation | Response |
|-----------|----------|
| Component is not `Slider` | `logWarning`, returns `nil` from `AddDriver` |
| Driver not found | `logWarning`, returns `nil` from `GetDriver` |

All errors are logged via `logWarning` with the `[SLIDER DRIVER]:` prefix. The driver has no runtime error scenarios for `:SetValue()`, `:GetValue()`, or `:IsMoving()` — these always succeed regardless of state.

---

## Usage Examples

### Basic Value Reading

```lua
local slider = KRNL.GetDriver("slider1")

-- Read the current value
local v = slider:GetValue()
print(string.format("Slider value: %.2f", v))

-- Check if the user is currently dragging it
if slider:IsMoving() then
    print("Slider is being moved")
end
```

### Reacting to Changes

```lua
local slider = KRNL.GetDriver("slider1")
local lastValue = slider:GetValue()

slider.ValueChanged:Connect(function()
    local current = slider:GetValue()
    local delta = current - lastValue
    print(string.format("Slider moved: %.2f -> %.2f (delta: %+.2f)", lastValue, current, delta))
    lastValue = current
end)
```

### Setting Value Programmatically

```lua
local slider = KRNL.GetDriver("slider1")

-- Reset slider to center
slider:SetValue(50)

-- The ValueChanged event will fire on the next update() tick
```

### Controlling Volume with a Slider

```lua
local slider = KRNL.GetDriver("volume_knob")
local audio = KRNL.GetDriver("audio")

slider.ValueChanged:Connect(function()
    local vol = slider:GetValue()
    audio:SetMasterVolume(vol)
    print(string.format("Volume set to: %.0f%%", vol))
end)
```

---

## Method Reference

| Method | Returns | Description |
|--------|---------|-------------|
| `SetValue(value)` | `void` | Set the hardware slider value |
| `GetValue()` | `number` | Get the cached slider value |
| `IsMoving()` | `boolean` | Check if the slider is being moved |

### Events

| Event | Payload | Description |
|-------|---------|-------------|
| `ValueChanged` | none | Fired when the slider value changes between ticks |

---

## Limitations
- **No delta or direction info** — `ValueChanged` does not include the old/new values or direction in its payload. Consumers must track the previous value themselves if they need deltas.
