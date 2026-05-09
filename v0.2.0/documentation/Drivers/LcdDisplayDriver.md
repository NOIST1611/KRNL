# LCD Display Driver

The **LCD Display Driver** wraps a Retro Gadgets `LcdDisplay` component and provides text output, line-based formatting, centering, and color management. The LCD has a fixed 32-character buffer divided into two 16-character lines.

---

## Overview

The LCD Display is one of the primary output devices in Retro Gadgets. It renders a single string of up to 32 characters with configurable foreground and background colors. The driver abstracts the raw hardware into a convenient line-based API: the display is treated as two lines of 16 characters each, with automatic padding and truncation.

**Key features:**

* **Text management** — Set, get, and clear the 32-character display buffer.
* **Line-based output** — Write to individual lines (1 or 2) with automatic truncation at 16 characters.
* **Text centering** — Center text within a 16-character line using automatic padding.
* **Color control** — Set and retrieve background and text colors using the `Color4` utility.
* **Safe defaults** — Initializes with a black background and white text on driver creation.

---

## Display Layout

The LCD display buffer is a single 32-character string. The driver logically divides it into two lines:

```
Line 1: Characters 1–16   (first half of the buffer)
Line 2: Characters 17–32  (second half of the buffer)
```

```
┌──────────────────────┐
│  Line 1 (16 chars)   │  ← positions 1–16
├──────────────────────┤
│  Line 2 (16 chars)   │  ← positions 17–32
└──────────────────────┘
```

When using `SetText()`, the entire 32-character buffer is replaced. When using `PrintLine()`, only the corresponding 16-character half is modified. All methods that write to the display enforce the 32-character limit.

---

## Accessing the LCD Driver

```lua
local KRNL = require("/KRNL/OS")

-- By instance name
local lcd = KRNL.GetDriver("Lcd0")

-- The LCD driver is named based on the component instance name,
-- e.g. "Lcd0", "LcdDisplay0", etc.
```

---

## API Reference

### `Lcd.AddDriver(instance: LcdDisplay, name: string, registry: DriverRegistry): LcdDriver?`

Static factory method. Creates a new LCD driver instance and registers it in the driver registry. This is called internally by the kernel during boot — you do not typically call this directly.

* **instance**: The Retro Gadgets `LcdDisplay` component instance.
* **name**: The driver instance name (e.g., `"Lcd0"`).
* **registry**: The kernel's driver registry table.
* **Returns**: A new `LcdDriver` instance, or `nil` if the component type is invalid.

**Initialization process:**

1. Validates that `instance.Type == "LcdDisplay"`. If not, logs a warning and returns `nil`.
2. Creates the driver object via `setmetatable({}, Lcd)`.
3. Stores the hardware reference in `driver.instance`.
4. Initializes `_driverData` with default userdata:
   * `bg_color` = `Color4.FromRGB(0, 0, 0)` (black)
   * `text_color` = `Color4.FromRGB(255, 255, 255)` (white)
5. Registers the driver in the `registry` table under `name`.
6. Applies the default colors to the hardware component.

---

### `Lcd.GetDriver(name: string, registry: DriverRegistry): LcdDriver?`

Static lookup method. Retrieves a previously registered LCD driver from the registry. This is called internally by `KRNL.GetDriver()`.

* **name**: The driver instance name to look up.
* **registry**: The kernel's driver registry table.
* **Returns**: The `LcdDriver` instance, or `nil` if not found (with a warning logged).

---

### `lcd:SetText(text: string): ()`

Sets the entire display text. If the provided text exceeds 32 characters, it is silently truncated to the first 32 characters.

* **text**: The text string to display (max 32 characters, longer strings are truncated).

```lua
lcd:SetText("Hello, World!")
lcd:SetText("This text is way too long and will be truncated to exactly 32 chars")
-- Display shows: "This text is way too long an"
```

> **Note:** Strings shorter than 32 characters are not automatically padded. To fill the entire display, use `Clear()` first or pad the string manually.

---

### `lcd:GetText(): string`

Returns the current text displayed on the LCD.

* **Returns**: The current 32-character display string.

```lua
local current = lcd:GetText()
print("Display: [" .. current .. "]")
```

---

### `lcd:Clear(): ()`

Clears the display by filling it with 32 space characters. This is equivalent to `SetText((" "):rep(32))`.

```lua
lcd:Clear()
-- Display is now blank (all spaces)
```

> **Tip:** Always call `Clear()` before writing to individual lines with `PrintLine()` if you want to ensure no leftover characters from previous content appear.

---

### `lcd:PrintLine(line: number, text: string): ()`

Writes text to a specific line of the display. Only the corresponding 16-character half of the buffer is modified — the other line remains unchanged.

* **line**: The line number. Must be `1` (top line) or `2` (bottom line).
* **text**: The text to display on that line. Automatically truncated to 16 characters.

**Behavior:**

1. The input text is truncated to 16 characters: `text:sub(1, 16)`.
2. The current display content is retrieved via `GetText()`.
3. If the current text is shorter than 32 characters, it is padded with spaces to fill the buffer.
4. For **line 1**: the first 16 characters of the buffer are replaced with the new text.
5. For **line 2**: the last 16 characters of the buffer (positions 17–32) are replaced with the new text.
6. Any line number other than `1` or `2` logs a warning and does nothing.

```
Before PrintLine(1, "Status"):
┌──────────────────────┐
│  Old content 1       │
│  Old content 2       │
└──────────────────────┘

After PrintLine(1, "Status"):
┌──────────────────────┐
│  Status         │  ← line 1 replaced, padded with spaces
│  Old content 2       │  ← line 2 unchanged
└──────────────────────┘
```

```lua
lcd:Clear()
lcd:PrintLine(1, "Temperature")
lcd:PrintLine(2, "42 C")
-- Display shows: "Temperature    42 C           "

lcd:PrintLine(1, "KRNL v0.2.0")  -- 11 chars, padded to 16
lcd:PrintLine(2, "System Ready") -- 12 chars, padded to 16
```

> **Important:** Line numbers are **1-indexed** (line 1 = top, line 2 = bottom). Passing `0` or any value other than `1` or `2` triggers a warning and the call is ignored.

---

### `lcd:CenterLine(line: number, text: string): ()`

Writes centered text to a specific line. The text is automatically padded on the left (and right if needed) to center it within the 16-character line width.

* **line**: The line number (`1` or `2`).
* **text**: The text to center.

**Centering algorithm:**

1. Calculates the length of the input text.
2. Computes left padding: `pad = max(0, floor((16 - len) / 2))`.
3. Prepends `pad` spaces to the text.
4. Delegates to `PrintLine()` which handles truncation to 16 characters.

```
CenterLine(1, "Hello"):
  len = 5, pad = floor((16 - 5) / 2) = 5
  Result: "     Hello       " (5 spaces + "Hello" + 6 trailing spaces via PrintLine padding)

CenterLine(2, "OK"):
  len = 2, pad = floor((16 - 2) / 2) = 7
  Result: "       OK        " (7 spaces + "OK")

CenterLine(1, "This is a long string"):
  len = 21, pad = max(0, floor((16 - 21) / 2)) = 0
  Result: "This is a long s" (truncated to 16 by PrintLine)
```

```lua
lcd:Clear()
lcd:CenterLine(1, "KRNL v0.2.0")
lcd:CenterLine(2, "Loading...")
-- Display shows:
-- "   KRNL v0.2.0       Loading...      "
```

---

### `lcd:SetTextColor(color: Color4): ()`

Sets the text (foreground) color of the display. The color is stored internally and immediately applied to the hardware component.

* **color**: A `Color4` value representing the new text color.

```lua
local Color4 = require("/KRNL/kernel/Utils/Color4")

lcd:SetTextColor(Color4.FromRGB(0, 255, 0))   -- Green text
lcd:SetTextColor(Color4.FromRGB(255, 128, 0))  -- Orange text
```

---

### `lcd:SetBackgroundColor(color: Color4): ()`

Sets the background color of the display. The color is stored internally and immediately applied to the hardware component.

* **color**: A `Color4` value representing the new background color.

```lua
local Color4 = require("/KRNL/kernel/Utils/Color4")

lcd:SetBackgroundColor(Color4.FromRGB(0, 0, 40))  -- Dark blue background
lcd:SetBackgroundColor(Color4.FromRGB(20, 20, 20)) -- Dark grey background
```

---

### `lcd:GetTextColor(): Color4`

Returns the current text color.

* **Returns**: A `Color4` value representing the current text color.

```lua
local textColor = lcd:GetTextColor()
print("Text color:", textColor:Convert())
```

---

### `lcd:GetBackgroundColor(): Color4`

Returns the current background color.

* **Returns**: A `Color4` value representing the current background color.

```lua
local bgColor = lcd:GetBackgroundColor()
print("BG color:", bgColor:Convert())
```

---

## Internal Update Loop

The `_update()` method exists to satisfy the driver interface but contains no logic. The LCD driver does not require per-tick polling — all state changes are applied immediately when methods are called.

```
_update() flow:
  └─ (empty — no per-tick logic)
```

---

## Color4 Integration

The LCD driver uses the `Color4` utility for all color operations. Colors are stored internally as `Color4` values and converted to hardware-compatible format via `color:Convert()` before being applied to the display.

**Default colors on initialization:**

| Property | Color | RGB Value |
|---|---|---|
| Background | Black | `(0, 0, 0)` |
| Text | White | `(255, 255, 255)` |

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Invalid component type in `AddDriver` | Logs warning, returns `nil`. |
| Driver not found in `GetDriver` | Logs warning, returns `nil`. |
| Text exceeds 32 characters in `SetText` | Silently truncated to 32 characters. |
| Text exceeds 16 characters in `PrintLine` | Silently truncated to 16 characters. |
| Invalid line number in `PrintLine` / `CenterLine` | Logs warning, call is ignored. |
| Current text shorter than 32 chars in `PrintLine` | Automatically padded with spaces. |

The LCD driver never throws errors — all edge cases are handled gracefully with truncation, padding, or warning logs.

---

## Code Examples

### Basic Text Output

```lua
local KRNL = require("/KRNL/OS")
local lcd = KRNL.GetDriver("Lcd0")

lcd:Clear()
lcd:SetText("Hello, Retro Gadgets!")
```

### Two-Line Status Display

```lua
local KRNL = require("/KRNL/OS")
local lcd = KRNL.GetDriver("Lcd0")

lcd:Clear()
lcd:PrintLine(1, "KRNL v0.2.0")
lcd:PrintLine(2, "System Ready")
```

### Centered Title Screen

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local lcd = KRNL.GetDriver("Lcd0")

lcd:SetBackgroundColor(Color4.FromRGB(0, 0, 30))
lcd:SetTextColor(Color4.FromRGB(0, 200, 255))
lcd:Clear()

lcd:CenterLine(1, "KRNL")
lcd:CenterLine(2, "v0.2.0")
```

### Scrolling Text Effect

```lua
local KRNL = require("/KRNL/OS")
local lcd = KRNL.GetDriver("Lcd0")
local cpu = KRNL.GetDriver("CPU0")

local message = "  KRNL v0.2.0 — Welcome to the system  "
local offset = 1

KRNL.LaunchTask({
    name = "scroll_text",
    UpdateFunction = function(self)
        self.data.timer = (self.data.timer or 0) + cpu:GetDeltaTime()

        if self.data.timer >= 0.3 then
            self.data.timer = 0

            offset = (offset % #message) + 1
            local display = message:sub(offset) .. message:sub(1, offset - 1)
            display = display:sub(1, 32)

            lcd:SetText(display)
        end
    end,
    Data = {}
})
```

### Status Monitor with Blinking Indicator

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local lcd = KRNL.GetDriver("Lcd0")
local cpu = KRNL.GetDriver("CPU0")

local blinkOn = true

KRNL.LaunchTask({
    name = "status_monitor",
    UpdateFunction = function(self)
        self.data.timer = (self.data.timer or 0) + cpu:GetDeltaTime()

        -- Blink every 0.5 seconds
        if self.data.timer >= 0.5 then
            self.data.timer = 0
            blinkOn = not blinkOn

            if blinkOn then
                lcd:SetTextColor(Color4.FromRGB(0, 255, 0))
            else
                lcd:SetTextColor(Color4.FromRGB(0, 80, 0))
            end

            lcd:Clear()
            lcd:PrintLine(1, string.format("CPU: %d%%", cpu:GetUsage()))
            lcd:PrintLine(2, string.format("TPS: %.0f", cpu:GetTPS()))
        end
    end,
    Data = {}
})
```

### Boot Sequence Animation

```lua
local KRNL = require("/KRNL/OS")
local Color4 = require("/KRNL/kernel/Utils/Color4")
local lcd = KRNL.GetDriver("Lcd0")
local cpu = KRNL.GetDriver("CPU0")

-- Initialize display
lcd:SetBackgroundColor(Color4.FromRGB(0, 0, 0))
lcd:SetTextColor(Color4.FromRGB(255, 255, 255))
lcd:Clear()

local stages = {
    { text = "Initializing...", duration = 1.0 },
    { text = "Loading drivers", duration = 0.8 },
    { text = "Mounting VFS",    duration = 0.6 },
    { text = "Starting tasks",  duration = 0.5 },
    { text = "KRNL Ready!",     duration = 2.0 },
}

local stageIndex = 1
local stageTimer = 0

KRNL.LaunchTask({
    name = "boot_sequence",
    UpdateFunction = function(self)
        if stageIndex > #stages then
            self:SetState("idle")
            return
        end

        local stage = stages[stageIndex]
        local dt = cpu:GetDeltaTime()
        stageTimer = stageTimer + dt

        -- Show progress bar on line 1
        local progress = math.min(stageTimer / stage.duration, 1.0)
        local filled = math.floor(progress * 16)
        local bar = ("#"):rep(filled) .. ("-"):rep(16 - filled)

        lcd:Clear()
        lcd:PrintLine(1, bar)
        lcd:PrintLine(2, stage.text)

        if stageTimer >= stage.duration then
            stageTimer = 0
            stageIndex = stageIndex + 1
        end
    end,
    Data = {}
})
```

---

## Relationship to Other Components

| Component | Relationship |
|---|---|
| **Video Driver** | Alternative display driver for pixel-level rendering. Use the LCD driver for simple text output and the Video Driver for complex graphics. |
| **Color4 Utility** | Provides the `Color4` type used for all color operations. Colors are converted via `Color4:Convert()` before being sent to the hardware. |
| **CPU Driver** | Often used alongside the LCD driver for timing-based animations, status updates, and scheduled display changes. |
| **ROM Driver** | Can provide fonts and sprite assets for text rendering on more advanced display setups. |

---

## Limitations

* **Fixed 32-character buffer** — The LCD hardware supports exactly 32 characters. There is no scrolling or wrapping; all text must fit within this limit.
* **Two 16-character lines** — The display is divided into two fixed lines. There is no support for more lines or variable line widths.
* **Text-only output** — The LCD does not support pixel-level drawing, images, or custom fonts. For advanced graphics, use the `VideoDriver` instead.
* **No cursor control** — There is no blinking cursor, text insertion, or editing support. Each write operation replaces the target line entirely.
* **Immediate rendering** — All display changes are applied synchronously. There is no double buffering or frame-based rendering — calling `SetText()` followed by `PrintLine()` in the same tick will show both changes.
