# Keyboard Driver

The **Keyboard Driver** wraps a Retro Gadgets `KeyboardChip` component and provides key input buffering, held-key tracking, character resolution with shift/caps lock support, and event signals. It acts as a full input subsystem — converting raw hardware key events into typed text, managing an input buffer, and exposing both low-level (key press/release) and high-level (text input/submit) APIs.

---

## Overview

The Keyboard Chip in Retro Gadgets fires raw hardware events for every key press and release. The Keyboard Driver processes these events and provides two layers of abstraction: a low-level event system with `InputBegan` / `InputEnded` signals, and a high-level text buffer with `BufferChanged` / `BufferSubmit` signals. It handles character mapping, shift and caps lock state, backspace, and buffer limits — all automatically.

**Key features:**

* **Character resolution** — Converts hardware key names (e.g., `"Alpha5"`, `"Period"`) to printable characters, respecting shift and caps lock state.
* **Input buffer** — Maintains a typed text buffer with configurable length limit, backspace support, and Enter-to-submit.
* **Held-key tracking** — Tracks which keys are currently held down for continuous input detection.
* **Caps Lock** — Supports toggleable caps lock state via the `CapsLock` key.
* **Event signals** — Four signals (`InputBegan`, `InputEnded`, `BufferChanged`, `BufferSubmit`) for reactive programming.
* **Event channel hooking** — Returns the internal event handler for direct hardware event channel attachment.

---

## Accessing the Keyboard Driver

```lua
local KRNL = require("/KRNL/OS")

-- By instance name
local kb = KRNL.GetDriver("KeyboardChip0")

-- The keyboard driver is named based on the component instance name,
-- e.g. "KeyboardChip0", "KeyboardChip1", etc.
```

---

## Key Mapping Tables

The driver maintains two internal lookup tables that translate hardware key names into printable characters. These are not directly accessible but drive the `_resolveChar()` method.

### Base Characters (`KEY_BASE`)

Maps key names to their default (unshifted) character output:

| Key Name | Character | Key Name | Character |
|---|---|---|---|
| `Space` | ` ` (space) | `Alpha0`–`Alpha9` | `0`–`9` |
| `Period` | `.` | `Comma` | `,` |
| `Semicolon` | `;` | `Quote` | `'` |
| `Minus` | `-` | `Equals` | `=` |
| `Slash` | `/` | `Backslash` | `\` |
| `LeftBracket` | `[` | `RightBracket` | `]` |
| `Grave` | `` ` `` | `Keypad0`–`Keypad9` | `0`–`9` |
| `KeypadPlus` | `+` | `KeypadMinus` | `-` |
| `KeypadMultiply` | `*` | `KeypadDivide` | `/` |
| `KeypadPeriod` | `.` | `KeypadEquals` | `=` |

Alpha keys (`A`–`Z`) are handled separately by the single-character fallback logic (see [Character Resolution](#character-resolution-logic)).

### Shift Characters (`KEY_SHIFT`)

Maps key names to their shifted character output:

| Key Name | Character | Key Name | Character |
|---|---|---|---|
| `Alpha0`–`Alpha9` | `)` `!` `@` `#` `$` `%` `^` `&` `*` `(` | `Period` | `>` |
| `Comma` | `<` | `Semicolon` | `:` |
| `Quote` | `"` | `Minus` | `_` |
| `Equals` | `+` | `Slash` | `?` |
| `Backslash` | `\|` | `LeftBracket` | `{` |
| `RightBracket` | `}` | `Grave` | `~` |

---

## Event Signals

The Keyboard Driver exposes four signals created via `BetterEvents`:

| Signal | Fired When | Arguments |
|---|---|---|
| `InputBegan` | Any key is pressed down. | `(key: string)` — The hardware key name (e.g., `"AlphaA"`, `"Space"`, `"Return"`). |
| `InputEnded` | Any key is released. | `(key: string)` — The hardware key name. |
| `BufferChanged` | The input buffer content changes (character added, backspace, flush, or submit clear). | `(buffer: string)` — The current buffer content after the change. |
| `BufferSubmit` | Enter is pressed while there is content in the buffer. | `(buffer: string)` — The submitted buffer content (before it is cleared). |

Signal names follow the pattern `{instance_name}_{signal_name}` internally (e.g., `"KeyboardChip0_inputbegan"`).

```lua
local kb = KRNL.GetDriver("KeyboardChip0")

-- Low-level key detection
kb.InputBegan:Connect(function(key)
    print("Key pressed: " .. key)
end)

kb.InputEnded:Connect(function(key)
    print("Key released: " .. key)
end)

-- High-level text input
kb.BufferChanged:Connect(function(buffer)
    print("Buffer: [" .. buffer .. "]")
end)

kb.BufferSubmit:Connect(function(buffer)
    print("Submitted: [" .. buffer .. "]")
end)
```

---

## API Reference

### `Keyboard.AddDriver(instance: KeyboardChip, name: string, registry: DriverRegistry): KeyboardDriver?`

Static factory method. Creates a new Keyboard driver instance and registers it in the driver registry. Called internally by the kernel during boot.

* **instance**: The Retro Gadgets `KeyboardChip` component instance.
* **name**: The driver instance name (e.g., `"KeyboardChip0"`).
* **registry**: The kernel's driver registry table.
* **Returns**: A new `KeyboardDriver` instance, or `nil` if the component type is invalid.

**Initialization process:**

1. Validates that `instance.Type == "KeyboardChip"`. If not, logs a warning and returns `nil`.
2. Creates the driver object via `setmetatable({}, Keyboard)`.
3. Stores the hardware reference in `driver.instance`.
4. Initializes `_driverData` with default userdata:
   * `buffer` = `""` (empty input buffer)
   * `held_keys` = `{}` (no keys held)
   * `buffer_limit` = `64`
   * `caps_lock` = `false`
   * `event_function` = internal handler (see below)
5. Creates four signals via `BetterEvents.new()`:
   * `InputBegan`, `InputEnded`, `BufferChanged`, `BufferSubmit`
6. Registers the driver in the `registry` table under `name`.

---

### `Keyboard.GetDriver(name: string, registry: DriverRegistry): KeyboardDriver?`

Static lookup method. Retrieves a previously registered Keyboard driver from the registry.

* **name**: The driver instance name to look up.
* **registry**: The kernel's driver registry table.
* **Returns**: The `KeyboardDriver` instance, or `nil` if not found (with a warning logged).

---

### `Keyboard:_isShiftHeld(): boolean`

Internal method. Checks whether either Shift key is currently held down.

* **Returns**: `true` if `LeftShift` or `RightShift` is in `held_keys`.

Used by `_resolveChar()` to determine whether to apply shift character mappings.

---

### `Keyboard:_resolveChar(key: string): string?`

Internal method. Converts a hardware key name to a printable character, taking into account shift state, caps lock state, and special key filtering.

* **key**: The hardware key name string.
* **Returns**: A single character string, or `nil` if the key does not produce a printable character.

**Resolution logic (in order):**

1. **Non-printable keys** — Returns `nil` immediately for: `Return`, `Backspace`, `LeftShift`, `RightShift`, `LeftCtrl`, `RightCtrl`, `LeftAlt`, `RightAlt`, `Tab`, `Escape`, `CapsLock`, `Delete`, any key containing `"Arrow"`, `"Page"`, or matching `"F%d"` (function keys).

2. **Shifted symbols** — If Shift is held and the key exists in `KEY_SHIFT`, returns the shifted character.

3. **Base symbols and digits** — If the key exists in `KEY_BASE`, returns the base character (regardless of shift — shifted digits are handled in step 2, and shifted alpha keys are handled in step 4).

4. **Single-character fallback** — If the key name is exactly 1 character long (alpha keys like `"A"`, `"B"`, etc.), applies case logic:
   * If `caps_lock` is active and Shift is NOT held → uppercase.
   * If `caps_lock` is active and Shift IS held → lowercase (shift cancels caps lock).
   * If `caps_lock` is NOT active and Shift IS held → uppercase.
   * If neither → lowercase.

5. **No match** — Returns `nil`.

**Case resolution table:**

| Caps Lock | Shift | Result |
|---|---|---|
| Off | Off | lowercase |
| Off | On | uppercase |
| On | Off | uppercase |
| On | On | lowercase |

---

### `Keyboard:_handleBuffer(key: string): ()`

Internal method. Processes a key press event against the input buffer. Called automatically by the internal `event_function` when a key is pressed (`ButtonDown = true`).

* **key**: The hardware key name of the pressed key.

**Processing logic:**

1. **Enter (`Return`)** — Fires `BufferSubmit` with the current buffer content, then clears the buffer and fires `BufferChanged` with an empty string.
2. **Backspace** — If the buffer is not empty, removes the last character (`buffer:sub(1, -2)`) and fires `BufferChanged`.
3. **Buffer limit** — If the buffer length has reached `buffer_limit`, the key is ignored (no character appended).
4. **Normal character** — Resolves the character via `_resolveChar()`. If a printable character is produced, appends it to the buffer and fires `BufferChanged`.

---

### `kb:GetBuffer(): string`

Returns the current contents of the input buffer.

* **Returns**: The current buffer string (may be empty).

```lua
local currentInput = kb:GetBuffer()
print("User typed: " .. currentInput)
```

---

### `kb:Flush(): ()`

Clears the input buffer immediately. Fires `BufferChanged` with an empty string.

```lua
kb:Flush()
-- Buffer is now ""
-- BufferChanged signal fired with ""
```

> **Note:** `Flush()` does NOT fire `BufferSubmit`. It silently discards the buffer content. Use this to cancel user input without triggering submission handlers.

---

### `kb:IsCapsLockActive(): boolean`

Returns whether Caps Lock is currently toggled on.

* **Returns**: `true` if Caps Lock is active, `false` otherwise.

Caps Lock is toggled each time the `CapsLock` key is pressed. The toggle happens inside the internal `event_function` before the `InputBegan` signal fires.

```lua
if kb:IsCapsLockActive() then
    print("CAPS LOCK is ON")
end
```

---

### `kb:IsKeyHeld(key: string): boolean`

Checks whether a specific key is currently being held down.

* **key**: The hardware key name to check (e.g., `"Space"`, `"LeftShift"`, `"AlphaA"`).
* **Returns**: `true` if the key is in the `held_keys` table.

Keys are added to `held_keys` on `ButtonDown` and removed on `ButtonUp` (when `ButtonDown` is `false`).

```lua
-- Continuous movement while arrow key is held
KRNL.LaunchTask({
    name = "movement",
    UpdateFunction = function(self)
        if kb:IsKeyHeld("ArrowLeft") then
            print("Moving left")
        end
        if kb:IsKeyHeld("ArrowRight") then
            print("Moving right")
        end
    end
})
```

**Common key names for `IsKeyHeld`:**

| Key | Hardware Name |
|---|---|
| Arrow keys | `"ArrowLeft"`, `"ArrowRight"`, `"ArrowUp"`, `"ArrowDown"` |
| Shift | `"LeftShift"`, `"RightShift"` |
| Control | `"LeftCtrl"`, `"RightCtrl"` |
| Alt | `"LeftAlt"`, `"RightAlt"` |
| Space | `"Space"` |
| Tab | `"Tab"` |
| Escape | `"Escape"` |
| Alpha keys | `"A"`–`Z"` or `"AlphaA"`–`"AlphaZ"` (depends on firmware) |
| Function keys | `"F1"`–`"F12"` |

---

### `kb:SetBufferLimit(limit: number): ()`

Sets the maximum number of characters the input buffer can hold. Characters typed when the buffer is at the limit are silently dropped.

* **limit**: The new maximum buffer length. Must be a positive number.

The default limit is `64`.

```lua
kb:SetBufferLimit(32)  -- Limit to 32 characters
kb:SetBufferLimit(16)  -- Limit to 16 characters (matches LCD line width)
```

---

### `kb:HookEventChannel(): any`

Returns the internal event handler function for direct attachment to the KeyboardChip's hardware event channel. This is used internally by the kernel to wire up hardware events.

* **Returns**: The event handler function with signature `(sender: any, event: KeyboardChipEvent) -> ()`.

The returned function processes `KeyboardChipEvent` objects:
- Reads `event.InputName` as a string key name.
- On `event.ButtonDown == true`: updates `held_keys`, toggles Caps Lock if applicable, fires `InputBegan`, calls `_handleBuffer`.
- On `event.ButtonDown == false`: removes from `held_keys`, fires `InputEnded`.

> **Note:** In most cases you do not need to call this directly. The kernel handles event channel hooking during driver registration.

---

## Internal Update Loop

The `_update()` method exists to satisfy the driver interface but contains no logic. All keyboard input is handled reactively through the hardware event channel — no per-tick polling is required.

```
_update() flow:
  └─ (empty — all input is event-driven)
```

---

## Internal Event Flow

The following diagram shows how a single key press flows through the driver's internal pipeline:

```
Hardware Event (ButtonDown = true)
    │
    ▼
event_function(sender, event)
    │
    ├─ key = tostring(event.InputName)
    │
    ├─ held_keys[key] = true
    │
    ├─ if key == "CapsLock": toggle caps_lock
    │
    ├─ InputBegan:Fire(key)
    │
    └─ _handleBuffer(key)
         │
         ├─ "Return"  → BufferSubmit:Fire(buffer) → buffer = "" → BufferChanged:Fire("")
         ├─ "Backspace" → buffer = sub(1,-2) → BufferChanged:Fire(buffer)
         └─ normal key → resolveChar → append to buffer → BufferChanged:Fire(buffer)

Hardware Event (ButtonDown = false)
    │
    ▼
event_function(sender, event)
    │
    ├─ held_keys[key] = nil
    │
    └─ InputEnded:Fire(key)
```

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Invalid component type in `AddDriver` | Logs warning, returns `nil`. |
| Driver not found in `GetDriver` | Logs warning, returns `nil`. |
| Buffer at limit, character typed | Character is silently dropped. |
| Backspace on empty buffer | No action (buffer remains empty). |
| Enter on empty buffer | `BufferSubmit` fires with `""`, buffer is cleared. |
| Unrecognized key name | `_resolveChar` returns `nil`, buffer unchanged. |
| Flush called | Buffer cleared, `BufferChanged` fires with `""`, `BufferSubmit` does NOT fire. |

---

## Code Examples

### Basic Text Input with Submit

```lua
local KRNL = require("/KRNL/OS")
local kb = KRNL.GetDriver("KeyboardChip0")
local lcd = KRNL.GetDriver("Lcd0")

lcd:Clear()
lcd:PrintLine(1, ">")

kb.BufferChanged:Connect(function(buffer)
    lcd:PrintLine(1, "> " .. buffer)
end)

kb.BufferSubmit:Connect(function(buffer)
    lcd:PrintLine(2, "Got: " .. buffer)
end)
```

### Command-Line Interface

```lua
local KRNL = require("/KRNL/OS")
local kb = KRNL.GetDriver("KeyboardChip0")
local lcd = KRNL.GetDriver("Lcd0")
local cpu = KRNL.GetDriver("CPU0")

lcd:SetBackgroundColor(Color4.FromRGB(0, 0, 0))
lcd:SetTextColor(Color4.FromRGB(0, 255, 0))
lcd:Clear()

local function showPrompt()
    lcd:Clear()
    lcd:PrintLine(1, "KRNL> ")
end

showPrompt()

kb.BufferSubmit:Connect(function(cmd)
    lcd:Clear()

    if cmd == "help" then
        lcd:PrintLine(1, "Commands:")
        lcd:PrintLine(2, "help clear ver")
    elseif cmd == "clear" then
        lcd:Clear()
    elseif cmd == "ver" then
        lcd:PrintLine(1, "KRNL v0.2.0")
        lcd:PrintLine(2, "Retro Gadgets")
    else
        lcd:PrintLine(2, "Unknown: " .. cmd)
    end

    cpu:Delay(function()
        showPrompt()
    end, 1.5)
end)
```

### Key-Based Movement with Held Detection

```lua
local KRNL = require("/KRNL/OS")
local kb = KRNL.GetDriver("KeyboardChip0")

local playerX = 0
local playerY = 0

KRNL.LaunchTask({
    name = "player_movement",
    UpdateFunction = function(self)
        local dx = 0
        local dy = 0

        if kb:IsKeyHeld("ArrowLeft") or kb:IsKeyHeld("A") then
            dx = dx - 1
        end
        if kb:IsKeyHeld("ArrowRight") or kb:IsKeyHeld("D") then
            dx = dx + 1
        end
        if kb:IsKeyHeld("ArrowUp") or kb:IsKeyHeld("W") then
            dy = dy - 1
        end
        if kb:IsKeyHeld("ArrowDown") or kb:IsKeyHeld("S") then
            dy = dy + 1
        end

        if dx ~= 0 or dy ~= 0 then
            playerX = playerX + dx
            playerY = playerY + dy
            print(string.format("Position: %d, %d", playerX, playerY))
        end
    end
})
```

### Key Press Counter

```lua
local KRNL = require("/KRNL/OS")
local kb = KRNL.GetDriver("KeyboardChip0")

local pressCount = 0

kb.InputBegan:Connect(function(key)
    pressCount = pressCount + 1
    print(string.format("Press #%d: %s", pressCount, key))

    if kb:IsCapsLockActive() then
        print("  [CAPS]")
    end
    if kb:_isShiftHeld() then
        print("  [SHIFT]")
    end
end)
```

### Buffered Input with Length Limit

```lua
local KRNL = require("/KRNL/OS")
local kb = KRNL.GetDriver("KeyboardChip0")
local lcd = KRNL.GetDriver("Lcd0")

-- Match the LCD line width
kb:SetBufferLimit(16)

lcd:Clear()
lcd:PrintLine(2, "Max 16 chars")

kb.BufferChanged:Connect(function(buffer)
    local remaining = 16 - #buffer
    lcd:Clear()
    lcd:PrintLine(1, "> " .. buffer)
    lcd:PrintLine(2, remaining .. " chars left")
end)
```

### Multi-Key Combo Detection

```lua
local KRNL = require("/KRNL/OS")
local kb = KRNL.GetDriver("KeyboardChip0")

kb.InputBegan:Connect(function(key)
    -- Ctrl+C detection
    if kb:IsKeyHeld("LeftCtrl") and key == "C" then
        print("Ctrl+C pressed — cancelling operation")
    end

    -- Ctrl+Shift+S detection
    if kb:IsKeyHeld("LeftCtrl") and kb:IsKeyHeld("LeftShift") and key == "S" then
        print("Ctrl+Shift+S pressed — saving")
    end
end)
```

### Live Typing Echo with Caps Lock Indicator

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local kb = KRNL.GetDriver("KeyboardChip0")
local lcd = KRNL.GetDriver("Lcd0")

lcd:SetBackgroundColor(Color4.FromRGB(20, 20, 30))
lcd:SetTextColor(Color4.FromRGB(200, 200, 200))
lcd:Clear()

kb.BufferChanged:Connect(function(buffer)
    lcd:Clear()
    lcd:PrintLine(1, buffer)

    if kb:IsCapsLockActive() then
        lcd:SetTextColor(Color4.FromRGB(255, 200, 0))
        lcd:PrintLine(2, "[CAPS]")
        lcd:SetTextColor(Color4.FromRGB(200, 200, 200))
    end
end)
```

---

## Relationship to Other Components

| Component | Relationship |
|---|---|
| **CPU Driver** | Often used with `Delay()` for timed UI transitions after input events. |
| **LCD Driver** | Primary output target for keyboard input echo, prompts, and status display. |
| **BetterEvents** | Provides the `Signal` system used by all four keyboard signals. All signals are created via `BetterEvents.new()`. |
| **Video Driver** | Alternative output for more complex text rendering or cursor display based on keyboard input. |
| **Scheduler** | Tasks can poll `IsKeyHeld()` in their update loop for continuous movement or held-action detection. |

---

## Limitations

* **No cursor position** — The buffer is a simple append-only string. There is no cursor, no insertion at arbitrary positions, and no text selection.
* **No key repeat** — The driver does not implement key repeat (typematic repeat). Holding a key fires `InputBegan` once, followed by `BufferChanged` once.
* **No clipboard** — There is no copy, cut, or paste support. `Ctrl+C`, `Ctrl+V`, and similar combos are not handled.
* **Locale-independent** — The character mapping is US-ASCII only. There is no support for non-English layouts, accented characters, or Unicode input.
* **No key history** — The driver tracks only the current buffer and currently held keys. There is no history of previously submitted inputs or pressed keys.
* **Single buffer** — Only one input buffer exists per driver instance. For multi-field input (e.g., forms), manage multiple buffers in application logic.
* **Buffer limit applies to total length** — The limit counts all characters in the buffer, including those from previous submissions. After each `BufferSubmit`, the buffer resets to empty, so the limit applies per input session.
