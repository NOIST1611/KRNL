
#  LCD Driver Reference

The **LCD Driver** provides a high-level interface for managing 2-line, 32-character text displays

---

##  Accessing the Driver

To retrieve an LCD driver instance from the kernel:

```lua
local KRNL = require("/KRNL/OS")
local lcd = KRNL.GetDriver("Lcd0") -- Standard name is usually Lcd0

if not lcd then
    print("LCD component not found!")
end
```

---

##  Text Manipulation API

### `lcd:SetText(text: string)`
Sets the raw text of the entire display.
* **Constraints:** If the string is longer than 32 characters, it will be automatically truncated.
* **Usage:** Use this for full-screen updates or custom raw formatting.

### `lcd:PrintLine(line: number, text: string)`
Updates a specific line without affecting the other.
* **line**: Either `1` (top) or `2` (bottom).
* **text**: The string to display. Automatically truncated to 16 characters.
* **Behavior:** It preserves the content of the line not being edited.

### `lcd:CenterLine(line: number, text: string)`
Prints text centered horizontally on a specific line.
* **line**: `1` or `2`.
* **Behavior:** Calculates the necessary padding based on the 16-character limit.

### `lcd:Clear()`
Clears the entire display (fills it with 32 empty spaces).

### `lcd:GetText(): string`
Returns the current string displayed on the LCD.

---

##  Color Management

### `lcd:SetTextColor(color: Color4)`
Sets the color of the text.
* **Example:** ```lua
  local Color4 = KRNL.GetUtility("Color4")
  lcd:SetTextColor(Color4.FromRGB(255, 0, 0)) -- Set text to Red
  ```

### `lcd:SetBackgroundColor(color: Color4)`
Sets the background color of the display.

### `lcd:GetTextColor(): Color4` / `lcd:GetBackgroundColor(): Color4`
Returns the current `Color4` object stored in the driver's metadata.

---

##  Code Examples

### Simple Boot Screen
```lua
local function bootSequence()
    lcd:Clear()
    lcd:SetBackgroundColor(Color4.FromRGB(0, 0, 50)) -- Dark blue
    
    lcd:CenterLine(1, "KRNL NANO")
    lcd:CenterLine(2, "Loading...")
    
    -- Using CPU driver for a delayed effect
    cpu:Delay(function()
        lcd:PrintLine(2, "READY >")
    end, 2)
end
```

### Scrolling Text Wrapper (Concept)
Since the LCD is limited to 16 chars per line, you can use `PrintLine` to create scrolling effects:
```lua
local msg = "LONG MESSAGE THAT SCROLLS "
local pos = 1

KRNL.CreateTask({
    name = "Scroller",
    UpdateFunction = function()
        -- Update every ~0.2 seconds
        if math.floor(cpu:GetRuntime() * 5) % 1 == 0 then
            local display = msg:sub(pos, pos + 15)
            lcd:PrintLine(1, display)
            pos = pos + 1
            if pos > #msg then pos = 1 end
        end
    end
})
```

---
