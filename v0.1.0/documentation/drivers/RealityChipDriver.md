
---

# RealityChipDriver Reference

The **RealityChipDriver** is the gateway between the virtual KRNL environment and the host system.
---

## Accessing the Driver

```lua
local KRNL = require("/KRNL/OS")
local reality = KRNL.GetDriver("RealityChip")

if not reality then
    print("RealityChip not detected. External I/O disabled.")
end
```

---

## System Monitoring

Track how the gadget is performing relative to your host PC's resources.

| Method | Return Type | Description |
| :--- | :--- | :--- |
| `GetCPUUsage()` | `number` | Total CPU usage percentage of the host. |
| `GetCPUCoresUsage()` | `{ number }` | A table containing usage percentage for each individual core. |
| `GetRAMAvailable()` | `number` | Available system RAM (in MB). |
| `GetRAMUsed()` | `number` | Used system RAM (in MB). |
| `GetRAMTotal()` | `number` | Total combined RAM detected by the chip. |

---

## Time & Date Utilities

The driver provides formatted strings and raw tables for building system clocks and calendars.

### `reality:GetTimeString(): string`
Returns the current local time in `HH:MM:SS` format (e.g., `"14:30:05"`).

### `reality:GetDateString(): string`
Returns the current local date in `DD/MM/YYYY` format.

### `reality:GetFullDateTimeString(): string`
Combines both for a full timestamp.

### `reality:GetDateTime() / GetDateTimeUTC()`
Returns a raw table from the hardware:
`{ year, month, day, hour, min, sec, msec, dayOfWeek, dayOfYear }`

---

## External File System (I/O)

RealityChip can interact with the local file system.

### `reality:LoadSprite(filename, sw, sh)`
Loads a SpriteSheet from an external file.
* `sw`, `sh`: Sprite width and height.

### `reality:LoadAudio(filename)`
Loads an external audio file as an `AudioSample`.

### `reality:ListDir(directory): { string }`
Returns an array of filenames/folders within a specific directory. Essential for building "File Explorers".

### `reality:GetFileMeta(filename): table`
Returns metadata such as file size and creation date.

---

## Network Statistics
Monitor the data flow through the host network interface.
* `GetNetworkSent()`: Total data sent (bytes).
* `GetNetworkReceived()`: Total data received (bytes).

---

## Code Example: System Dashboard

```lua
local video = KRNL.GetDriver("VideoChip")
local reality = KRNL.GetDriver("RealityChip")

KRNL.CreateTask({
    name = "StatusTask",
    UpdateFunction = function()
        video:FrameStart()
        
        local timeStr = reality:GetTimeString()
        local ramUsed = math.floor(reality:GetRAMUsed())
        local cpuLoad = math.floor(reality:GetCPUUsage())
        
        video:DrawText(5, 5, FONT, "TIME: " .. timeStr, color.white)
        video:DrawText(5, 15, FONT, "CPU: " .. cpuLoad .. "%", color.green)
        video:DrawText(5, 25, FONT, "RAM: " .. ramUsed .. "MB", color.cyan)
        
        video:FrameEnd()
    end
})
```

---
