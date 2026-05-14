# Reality Chip Driver

The **Reality Chip Driver** wraps a Retro Gadgets `RealityChip` component and provides a bridge between the virtual gadget world and the real host system. It exposes real-time system information (CPU, RAM, network), date and time utilities, and the ability to load external assets from the host filesystem.

---

## Overview

The Reality Chip is a special component that breaks the sandbox boundary — it allows Lua scripts to query the host computer's hardware metrics, access the system clock, and load files from the real filesystem

**Key features:**

* **System metrics** — Real CPU usage (total and per-core), RAM availability, network I/O statistics.
* **Date and time** — Local and UTC datetime objects, formatted time/date strings, and a combined full datetime string.
* **Asset loading** — Load sprite sheets and audio samples from the host filesystem, list directories, and query file metadata.

---

## Accessing the Reality Chip Driver

```lua
local KRNL = require("/KRNL/OS")

local reality = KRNL.GetDriver("RealityChip")
```

---

## API Reference

### System Information Methods

#### `reality:GetCPUUsage(): number`

Returns the overall CPU usage of the host system as a value between `0` and `1`.

* **Returns**: Total CPU usage as a fraction (e.g., `0.45` means 45% CPU usage).

```lua
local usage = reality:GetCPUUsage()
print(string.format("Host CPU: %.1f%%", usage * 100))
```

---

#### `reality:GetCPUCoresUsage(): { number }`

Returns an array of per-core CPU usage values, each between `0` and `1`.

* **Returns**: A numerically-indexed table where each element is a core's usage fraction (e.g., `{0.3, 0.8, 0.1, 0.05}` for a 4-core system).

The array length corresponds to the number of CPU cores on the host system.

```lua
local cores = reality:GetCPUCoresUsage()
print(string.format("CPU Cores: %d", #cores))
for i, usage in ipairs(cores) do
    print(string.format("  Core %d: %.1f%%", i, usage * 100))
end
```

---

#### `reality:GetRAMAvailable(): number`

Returns the amount of available (free) RAM on the host system, in bytes.

* **Returns**: Available RAM in bytes.

```lua
local available = reality:GetRAMAvailable()
print(string.format("Available RAM: %.1f MB", available / (1024 * 1024)))
```

---

#### `reality:GetRAMUsed(): number`

Returns the amount of currently used RAM on the host system, in bytes.

* **Returns**: Used RAM in bytes.

```lua
local used = reality:GetRAMUsed()
print(string.format("Used RAM: %.1f MB", used / (1024 * 1024)))
```

---

#### `reality:GetRAMTotal(): number`

Returns the total amount of RAM on the host system, in bytes. This is computed as `Available + Used`.

* **Returns**: Total RAM in bytes.

> **Note:** This is not a direct hardware read — it is calculated as `GetRAMAvailable() + GetRAMUsed()`. The result may not exactly match the host's reported total due to OS-level memory management (cached, buffered, etc.).

```lua
local total = reality:GetRAMTotal()
local used = reality:GetRAMUsed()
local pct = (used / total) * 100
print(string.format("RAM: %.1f / %.1f MB (%.1f%%)", used / 1e6, total / 1e6, pct))
```

---

### Network Methods

#### `reality:GetNetworkSent(): number`

Returns the total number of bytes sent over the network by the host system since Retro Gadgets started (or since the last OS reset).

* **Returns**: Total bytes sent.

```lua
local sent = reality:GetNetworkSent()
print(string.format("Network sent: %.1f KB", sent / 1024))
```

---

#### `reality:GetNetworkReceived(): number`

Returns the total number of bytes received over the network by the host system since Retro Gadgets started (or since the last OS reset).

* **Returns**: Total bytes received.

```lua
local received = reality:GetNetworkReceived()
print(string.format("Network received: %.1f KB", received / 1024))
```

---

### Date & Time Methods

#### `reality:GetDateTime(): any`

Returns the current local date and time as a table with individual fields.

* **Returns**: A table with the following fields:

| Field | Type | Description |
|---|---|---|
| `year` | `number` | Full year (e.g., `2026`). |
| `month` | `number` | Month (1–12). |
| `day` | `number` | Day of month (1–31). |
| `yday` | `number` | Day of year (1–366). |
| `wday` | `number` | Day of week (1–7, Sunday = 1). |
| `hour` | `number` | Hour (0–23). |
| `min` | `number` | Minute (0–59). |
| `sec` | `number` | Second (0–59). |
| `isdst` | `boolean` | Whether daylight saving time is active. |

```lua
local dt = reality:GetDateTime()
print(string.format("%04d-%02d-%02d %02d:%02d:%02d", dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec))
print(string.format("Day of year: %d", dt.yday))
print(string.format("Day of week: %d", dt.wday))
```

---

#### `reality:GetDateTimeUTC(): any`

Returns the current UTC date and time as a table with the same fields as `GetDateTime()`, but in Coordinated Universal Time instead of local time.

* **Returns**: A table with the same structure as `GetDateTime()`, adjusted to UTC.

```lua
local dt = reality:GetDateTimeUTC()
print(string.format("UTC: %02d:%02d:%02d", dt.hour, dt.min, dt.sec))
```

---

#### `reality:GetTimeString(): string`

Returns the current local time as a formatted string in `HH:MM:SS` format.

* **Returns**: A string like `"14:30:05"`.

```lua
local time = reality:GetTimeString()
print("Current time: " .. time)
```

---

#### `reality:GetDateString(): string`

Returns the current local date as a formatted string in `DD/MM/YYYY` format.

* **Returns**: A string like `"15/05/2026"`.

```lua
local date = reality:GetDateString()
print("Today: " .. date)
```

---

#### `reality:GetFullDateTimeString(): string`

Returns the current local date and time as a combined formatted string.

* **Returns**: A string like `"14:30:05 15/05/2026"` (time followed by a space and date).

This is a convenience method equivalent to `GetTimeString() .. " " .. GetDateString()`, but with only one hardware call (it fetches the datetime object once and formats both parts).

```lua
local full = reality:GetFullDateTimeString()
print("Now: " .. full)
```

---

### Asset Methods

#### `reality:LoadSprite(filename: string, sw: number, sh: number): SpriteSheet`

Loads a sprite sheet from the host filesystem and returns it as a `SpriteSheet` asset.

* **filename**: Path to the image file on the host filesystem (relative or absolute, depending on Retro Gadgets conventions).
* **sw**: Sprite width in pixels — each sprite cell on the sheet has this width.
* **sh**: Sprite height in pixels — each sprite cell on the sheet has this height.
* **Returns**: A `SpriteSheet` asset that can be used with the Video Driver's `DrawSprite` and `RasterSprite` methods.

The loaded sprite sheet behaves identically to ROM-bundled sprite sheets. Once loaded, it can be used anywhere a `SpriteSheet` is accepted.

```lua
local playerSheet = reality:LoadSprite("assets/player.png", 32, 32)
if playerSheet then
    video:DrawSprite(10, 10, playerSheet, 0, 0)
end
```

---

#### `reality:LoadAudio(filename: string): AudioSample`

Loads an audio sample from the host filesystem and returns it as an `AudioSample` asset.

* **filename**: Path to the audio file on the host filesystem.
* **Returns**: An `AudioSample` asset

```lua
local bgm = reality:LoadAudio("assets/music.wav")
if bgm then
    local ch = audio:ClaimAny(bgm, { AutoFree = false })
    if ch then
        audio:PlayLoop(ch)
    end
end
```

---

#### `reality:UnloadAsset(filename: string): ()`

Unloads a previously loaded asset from memory. The asset will no longer be accessible after unloading.

* **filename**: The filename of the asset to unload (must match the path used in `LoadSprite` or `LoadAudio`).

Use this to free memory when assets are no longer needed, especially for large sprite sheets or long audio files.

```lua
reality:UnloadAsset("assets/intro_music.wav")
reality:UnloadAsset("assets/background.png")
```

---

#### `reality:ListDir(directory: string): { string }`

Lists the contents of a directory on the host filesystem.

* **directory**: The directory path to list.
* **Returns**: A numerically-indexed table of filenames/directory names. Returns an empty table if the directory does not exist or is empty.

This is useful for discovering available assets at runtime without hardcoding filenames.

```lua
local files = reality:ListDir("assets/sprites")
for _, file in ipairs(files) do
    print("Found: " .. file)
end
```

---

#### `reality:GetFileMeta(filename: string): any`

Returns metadata for a file on the host filesystem.

* **filename**: The file path to query.
* **Returns**: A metadata object. The exact fields depend on the Retro Gadgets API, but typically include file size, modification date, and type information.

```lua
local meta = reality:GetFileMeta("assets/player.png")
if meta then
    print("File size: " .. tostring(meta.Size))
end
```

---

## Internal Update Loop

The `_update()` method exists to satisfy the driver interface but contains no logic. All Reality Chip methods query the hardware directly on each call — no per-tick polling or state accumulation is needed.

```
_update() flow:
  └─ (empty — all data is read on-demand from hardware)
```

---

## Error Handling

| Scenario | Behavior |
|---|---|
| `LoadSprite` with non-existent file | Returns `nil` (hardware behavior). |
| `LoadAudio` with non-existent file | Returns `nil` (hardware behavior). |
| `ListDir` with non-existent directory | Returns empty table `{}`. |
| `GetFileMeta` with non-existent file | Returns `nil` (hardware behavior). |
| `UnloadAsset` with non-loaded file | No-op (hardware behavior). |

---

## Code Examples

### System Monitor Dashboard

```lua
local KRNL = require("/KRNL/OS")
local reality = KRNL.GetDriver("RealityChip0")
local lcd = KRNL.GetDriver("Lcd0")
local cpu = KRNL.GetDriver("CPU0")

KRNL.LaunchTask({
    name = "sys_monitor",
    UpdateFunction = function(self)
        self.data.timer = (self.data.timer or 0) + cpu:GetDeltaTime()

        if self.data.timer >= 1.0 then
            self.data.timer = 0

            local hostCPU = reality:GetCPUUsage()
            local ramTotal = reality:GetRAMTotal()
            local ramUsed = reality:GetRAMUsed()
            local ramPct = ramUsed / ramTotal * 100
            local sent = reality:GetNetworkSent()
            local recv = reality:GetNetworkReceived()

            lcd:Clear()
            lcd:PrintLine(1, string.format("H:%.0f%% R:%.0f%%", hostCPU * 100, ramPct))
            lcd:PrintLine(2, string.format("N:%.1fK", (sent + recv) / 1024))
        end
    end
})
```

### Real-Time Clock Display

```lua
local KRNL = require("/KRNL/OS")
local reality = KRNL.GetDriver("RealityChip0")
local lcd = KRNL.GetDriver("Lcd0")
local cpu = KRNL.GetDriver("CPU0")

KRNL.LaunchTask({
    name = "clock",
    UpdateFunction = function(self)
        self.data.timer = (self.data.timer or 0) + cpu:GetDeltaTime()

        if self.data.timer >= 1.0 then
            self.data.timer = 0
            lcd:Clear()
            lcd:CenterLine(1, reality:GetTimeString())
            lcd:CenterLine(2, reality:GetDateString())
        end
    end
})
```

### Per-Core CPU Display

```lua
local KRNL = require("/KRNL/OS")
local reality = KRNL.GetDriver("RealityChip0")
local cpu = KRNL.GetDriver("CPU0")

KRNL.LaunchTask({
    name = "core_monitor",
    UpdateFunction = function(self)
        self.data.timer = (self.data.timer or 0) + cpu:GetDeltaTime()

        if self.data.timer >= 0.5 then
            self.data.timer = 0
            local cores = reality:GetCPUCoresUsage()

            local line = ""
            for i, usage in ipairs(cores) do
                local bars = math.floor(usage * 5)
                line = line .. string.rep("#", bars) .. string.rep("-", 5 - bars)
                if i < #cores then
                    line = line .. " "
                end
            end
            print(string.format("CPU [%s]", line))
        end
    end
})
```

### Network I/O Tracker

```lua
local KRNL = require("/KRNL/OS")
local reality = KRNL.GetDriver("RealityChip0")
local cpu = KRNL.GetDriver("CPU0")

local lastSent = 0
local lastRecv = 0

KRNL.LaunchTask({
    name = "net_tracker",
    UpdateFunction = function(self)
        self.data.timer = (self.data.timer or 0) + cpu:GetDeltaTime()

        if self.data.timer >= 2.0 then
            self.data.timer = 0

            local sent = reality:GetNetworkSent()
            local recv = reality:GetNetworkReceived()

            local sentDelta = sent - lastSent
            local recvDelta = recv - lastRecv
            local elapsed = 2.0

            local sentRate = sentDelta / elapsed
            local recvRate = recvDelta / elapsed

            print(string.format("Network: ↑%.1f KB/s ↓%.1f KB/s",
                sentRate / 1024, recvRate / 1024))
            print(string.format("Total: ↑%.1f KB ↓%.1f KB",
                sent / 1024, recv / 1024))

            lastSent = sent
            lastRecv = recv
        end
    end
})
```

### Dynamic Asset Loading from Filesystem

```lua
local KRNL = require("/KRNL/OS")
local reality = KRNL.GetDriver("RealityChip0")
local video = KRNL.GetDriver("VideoChip0")
local audio = KRNL.GetDriver("AudioChip0")

-- Discover available sprites
local sprites = reality:ListDir("assets/sprites")
local spriteCache = {}

for _, file in ipairs(sprites) do
    if file:match("%.png$") then
        local sheet = reality:LoadSprite("assets/sprites/" .. file, 32, 32)
        if sheet then
            local name = file:gsub("%.png$", "")
            spriteCache[name] = sheet
            print("Loaded sprite: " .. name)
        end
    end
end

-- Discover and load audio
local sounds = reality:ListDir("assets/audio")
for _, file in ipairs(sounds) do
    if file:match("%.wav$") then
        local sample = reality:LoadAudio("assets/audio/" .. file)
        if sample then
            local name = file:gsub("%.wav$", "")
            print("Loaded audio: " .. name)
        end
    end
end
```

### File Metadata Inspection

```lua
local KRNL = require("/KRNL/OS")
local reality = KRNL.GetDriver("RealityChip0")

local function inspectDirectory(path)
    print("=== " .. path .. " ===")
    local files = reality:ListDir(path)
    for _, file in ipairs(files) do
        local fullPath = path .. "/" .. file
        local meta = reality:GetFileMeta(fullPath)
        if meta then
            print(string.format("  %-30s %s", file, tostring(meta.Size or "?")))
        else
            print(string.format("  %-30s <dir or inaccessible>", file))
        end
    end
end

inspectDirectory("assets")
inspectDirectory("assets/sprites")
inspectDirectory("assets/audio")
```

### Day-Aware Greeting

```lua
local KRNL = require("/KRNL/OS")
local reality = KRNL.GetDriver("RealityChip0")

local dt = reality:GetDateTime()
local greetings = {
    [1] = "Happy Sunday!",
    [2] = "Happy Monday!",
    [3] = "Happy Tuesday!",
    [4] = "Happy Wednesday!",
    [5] = "Happy Thursday!",
    [6] = "Happy Friday!",
    [7] = "Happy Saturday!",
}

local greeting = greetings[dt.wday] or "Hello!"
local timeGreeting = ""

if dt.hour < 12 then
    timeGreeting = "Good morning"
elseif dt.hour < 18 then
    timeGreeting = "Good afternoon"
else
    timeGreeting = "Good evening"
end

print(timeGreeting .. "! " .. greeting)
```

---

## Relationship to Other Components

| Component | Relationship |
|---|---|
| **CPU Driver** | The CPU Driver estimates gadget-side load from frame timing. The Reality Driver provides real host CPU metrics. They measure different things. |
| **ROM Driver** | ROM provides bundled, read-only assets. The Reality Driver loads assets from the host filesystem at runtime. They serve complementary purposes — use ROM for always-available assets and Reality for user-customizable content. |
| **Video Driver** | Sprite sheets loaded via `LoadSprite()` can be passed directly to the Video Driver for rendering. |
| **Audio Driver** | Audio samples loaded via `LoadAudio()` can be passed directly to the Audio Driver for playback. |

---

## Reality Driver vs ROM Driver

| Aspect | Reality Driver (Assets) | ROM Driver |
|---|---|---|
| Source | Host filesystem | Bundled in gadget |
| Persistence | Files must exist on the host machine | Always available, packaged with the gadget |
| Loading | `LoadSprite`, `LoadAudio` | `GetSprite`, `GetAudio` |
| Listing | `ListDir` (any directory) | `ListSprites`, `ListAudio` (ROM contents only) |
| Unloading | `UnloadAsset` | No unloading needed (always in memory) |
| Portability | Not portable — depends on host file layout | Fully portable — travels with the gadget |
| Use case | User-customizable skins, mods, local assets | Core game assets, fonts, built-in resources |

---

## Limitations

* **Network counters are cumulative** — `GetNetworkSent()` and `GetNetworkReceived()` return totals since Retro Gadgets started, not per-frame deltas. Calculate deltas manually by storing previous values.
* **RAM calculation** — `GetRAMTotal()` is computed as `Available + Used`, which may not exactly match the host's actual total RAM due to OS memory management (shared GPU memory, kernel reservations, etc.).
* **Timezone-dependent** — `GetDateTime()`, `GetTimeString()`, and `GetDateString()` return local time based on the host system's timezone configuration. Use `GetDateTimeUTC()` for timezone-independent time.
* **No asset validation** — `LoadSprite()` and `LoadAudio()` do not validate file formats. Loading a non-image file as a sprite or a non-audio file as a sample will produce undefined behavior.
* **Date format is fixed** — `GetDateString()` uses `DD/MM/YYYY` format. There is no way to customize the format or locale. For custom formats, use `GetDateTime()` and build the string manually.
