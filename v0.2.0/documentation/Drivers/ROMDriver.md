# ROM Driver

The **ROM Driver** wraps a Retro Gadgets `ROM` component and provides access to all embedded assets stored on the Gadget — sprite sheets, audio samples, code snippets, and generic assets. The ROM acts as a read-only storage medium for resources that ship with the gadget, split into two namespaces: **User** assets (custom content added in the editor) and **System** assets (built-in resources provided by Retro Gadgets).

---

## Overview

Every Retro Gadgets gadget can include one ROM.ROM holds a collection of assets organized into categories: sprite sheets, audio samples, code snippets, and generic assets. These are packaged with the gadget and available at runtime without any file I/O or network access.

The ROM Driver provides a clean typed API for retrieving assets by name, with automatic warning logs when assets are missing. It distinguishes between **User** assets (content you add in the Retro Gadgets editor) and **System** assets (built-in resources like `StandardFont`).

**Key features:**

* **Sprite sheets** — Retrieve user and system sprite sheets for 2D rendering and texture mapping.
* **Standard font** — Quick access to the built-in system font for text rendering.
* **Audio samples** — Retrieve user and system audio for playback via the Audio Driver.
* **Code snippets** — Retrieve embedded Lua code assets for dynamic execution.
* **Generic assets** — Access the raw asset table for any asset type.
* **Asset listing** — Enumerate all asset names within a category for discovery.

---

## Accessing the ROM Driver

```lua
local KRNL = require("/KRNL/OS")

-- By instance name
local rom = KRNL.GetDriver("ROM0")

-- The ROM driver is named based on the component instance name,
-- e.g. "ROM0", "ROM1", "DataROM", etc.
```

---

## Asset Namespaces

The ROM chip organizes assets into two top-level namespaces:

### User Assets (`instance.User`)

Custom content added in the Retro Gadgets editor. This is where your gadget-specific sprites, sounds, code, and other resources live.

| Category | Property | Type | Description |
|---|---|---|---|
| Sprite Sheets | `User.SpriteSheets` | `{ [string]: SpriteSheet }` | User-uploaded sprite sheets. |
| Audio Samples | `User.AudioSamples` | `{ [string]: AudioSample }` | User-uploaded audio files. |
| Code Snippets | `User.Codes` | `{ [string]: Code }` | User-created Lua code snippets. |
| Generic Assets | `User.Assets` | `{ [string]: any }` | All generic user assets. |

### System Assets (`instance.System`)

Built-in resources provided by Retro Gadgets. These are always available and do not require any user action.

| Category | Property | Type | Description |
|---|---|---|---|
| Sprite Sheets | `System.SpriteSheets` | `{ [string]: SpriteSheet }` | System sprite sheets, including `StandardFont`. |
| Audio Samples | `System.AudioSamples` | `{ [string]: AudioSample }` | System audio samples. |

---

## API Reference

### Static Methods

#### `rom.AddDriver(instance: ROM, name: string, registry: DriverRegistry): RomDriver?`

Static factory method. Creates a new ROM driver and registers it in the driver registry. Called internally by the kernel during boot.

* **instance**: The Retro Gadgets `ROM` component instance.
* **name**: The driver instance name (e.g., `"ROM0"`).
* **registry**: The kernel's driver registry table.
* **Returns**: A new `RomDriver` instance, or `nil` if the component type is invalid.

**Initialization:**

1. Validates `instance.Type == "ROM"`.
2. Creates the driver via `setmetatable({}, rom)`.
3. Stores the hardware reference in `driver.instance`.
4. Initializes `_driverData` with an empty `userdata` table (no internal state needed).
5. Registers the driver in the `registry`.

---

#### `rom.GetDriver(name: string, registry: DriverRegistry): RomDriver?`

Static lookup method. Retrieves a previously registered ROM driver from the registry.

* **name**: The driver instance name.
* **registry**: The kernel's driver registry table.
* **Returns**: The `RomDriver` instance, or `nil` if not found (with a warning logged).

---

### Sprite Methods

#### `rom:GetSprite(name: string): SpriteSheet?`

Retrieves a sprite sheet from the **User** assets by name.

* **name**: The sprite sheet name as defined in the editor.
* **Returns**: A `SpriteSheet` asset, or `nil` if not found (with a warning logged).

```lua
local playerSheet = rom:GetSprite("player_sprites")
local tileSheet = rom:GetSprite("tileset")
```

---

#### `rom:GetSystemSprite(name: string): SpriteSheet?`

Retrieves a sprite sheet from the **System** assets by name.

* **name**: The system sprite sheet name.
* **Returns**: A `SpriteSheet` asset, or `nil` if not found (with a warning logged).

System sprite sheets are built-in resources provided by Retro Gadgets. Use this method when you need system-reserved sprites.

```lua
local systemIcons = rom:GetSystemSprite("Icons")
```

---

#### `rom:GetStandardFont(): SpriteSheet?`

Returns the built-in standard font sprite sheet. This is a convenience method that directly accesses `System.SpriteSheets["StandardFont"]`.

* **Returns**: The standard font `SpriteSheet`, or `nil` if not available.

> **Important:** Unlike other getter methods, `GetStandardFont()` does **not** log a warning if the font is missing. This is by design — it allows silent fallback handling.

```lua
local font = rom:GetStandardFont()

if font then
    video:DrawText(10, 10, font, "Hello!", color.white, nil)
end
```

The standard font is the primary way to render text on both the Video Chip

---

### Audio Methods

#### `rom:GetAudio(name: string): AudioSample?`

Retrieves an audio sample from the **User** assets by name.

* **name**: The audio sample name as defined in the editor.
* **Returns**: An `AudioSample` asset, or `nil` if not found (with a warning logged).

```lua
local bgm = rom:GetAudio("background_music")
local sfx = rom:GetAudio("click_sound")
```

---

#### `rom:GetSystemAudio(name: string): AudioSample?`

Retrieves an audio sample from the **System** assets by name.

* **name**: The system audio sample name.
* **Returns**: An `AudioSample` asset, or `nil` if not found (with a warning logged).

```lua
local beep = rom:GetSystemAudio("Beep")
```

---

### Code Methods

#### `rom:GetCode(name: string): Code?`

Retrieves a code snippet from the **User** assets by name.

* **name**: The code snippet name as defined in the editor.
* **Returns**: A `Code` asset, or `nil` if not found (with a warning logged).

Code snippets are Lua code blocks embedded in the ROM. They can be loaded and executed dynamically at runtime.

```lua
local myCode = rom:GetCode("utils")
-- Use with the ExecutionHandler or loadstring for dynamic execution
```

---

### Generic Asset Methods

#### `rom:GetAsset(name: string): any?`

Retrieves any asset from the **User** generic assets table by name.

* **name**: The asset name.
* **Returns**: The asset object (type depends on asset), or `nil` if not found (with a warning logged).

The `User.Assets` table contains all generic user assets. This is a catch-all category for asset types that don't fit into sprites, audio, or code.

```lua
local data = rom:GetAsset("level_data")
local config = rom:GetAsset("game_config")
```

---

#### `rom:ListAssets(): { string }`

Returns an array of all asset names in the **User** generic assets table.

* **Returns**: A numerically-indexed table of asset name strings. Empty table if no assets exist.

```lua
local assets = rom:ListAssets()
for _, name in ipairs(assets) do
    print("Asset: " .. name)
end
```

---

### Listing Methods

#### `rom:ListSprites(): { string }`

Returns an array of all sprite sheet names in the **User** assets.

* **Returns**: A numerically-indexed table of sprite sheet name strings.

```lua
local sprites = rom:ListSprites()
for _, name in ipairs(sprites) do
    print("Sprite: " .. name)
end
```

---

#### `rom:ListAudio(): { string }`

Returns an array of all audio sample names in the **User** assets.

* **Returns**: A numerically-indexed table of audio sample name strings.

```lua
local audioFiles = rom:ListAudio()
for _, name in ipairs(audioFiles) do
    print("Audio: " .. name)
end
```

---

## Asset Type Reference

The ROM Driver returns several Retro Gadgets asset types. Here is a summary of each:

| Type | Source | Used By | Description |
|---|---|---|---|
| `SpriteSheet` | `User.SpriteSheets` / `System.SpriteSheets` | Video Driver (`DrawSprite`, `DrawText`, `RasterSprite`), VideoTexture | A grid of sprite images. Used for rendering text and 2D graphics. |
| `AudioSample` | `User.AudioSamples` / `System.AudioSamples` | Audio Driver (`Claim`, `Play`) | A playable audio clip. Can be mono or stereo with various sample rates. |
| `Code` | `User.Codes` | Execution Handler, `loadstring` | A Lua code snippet stored as a text asset. |
| `any` | `User.Assets` | Application-dependent | A generic asset. The actual type depends on what was stored. |

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Invalid component type in `AddDriver` | Logs warning, returns `nil`. |
| Driver not found in `GetDriver` | Logs warning, returns `nil`. |
| Sprite not found (`GetSprite` / `GetSystemSprite`) | Logs warning with the asset name, returns `nil`. |
| Audio not found (`GetAudio` / `GetSystemAudio`) | Logs warning with the asset name, returns `nil`. |
| Code not found (`GetCode`) | Logs warning with the asset name, returns `nil`. |
| Asset not found (`GetAsset`) | Logs warning with the asset name, returns `nil`. |
| Standard font not found (`GetStandardFont`) | Returns `nil` **silently** (no warning). |

All warnings follow the format: `[ROM DRIVER]: <AssetType> '<name>' not found in User/System assets`.

---

## Code Examples

### Loading and Playing Audio

```lua
local KRNL = require("/KRNL/OS")
local rom = KRNL.GetDriver("ROM")
local audio = KRNL.GetDriver("AudioChip0")

-- Load audio assets
local bgm = rom:GetAudio("background_music")
local clickSfx = rom:GetAudio("click")

if bgm then
    local ch = audio:ClaimAny(bgm, { AutoFree = false })
    if ch then
        audio:PlayLoop(ch)
        audio:SetVolume(ch, 0.4)
    end
end

if clickSfx then
    local sfxCh = audio:ClaimAny(clickSfx, { AutoFree = true })
    if sfxCh then
        audio:Play(sfxCh)
    end
end
```

### Drawing Sprites

```lua
local KRNL = require("/KRNL/OS")
local rom = KRNL.GetDriver("ROM0")
local video = KRNL.GetDriver("VideoChip0")

local playerSheet = rom:GetSprite("player")
local tileSheet = rom:GetSprite("tiles")

video:FrameStart()
video:Clear(color.black)

-- Draw a tile from the tileset (column 2, row 1)
if tileSheet then
    video:DrawSprite(0, 0, tileSheet, 2, 1)
end

-- Draw the player sprite (column 0, row 0)
if playerSheet then
    video:DrawSprite(16, 16, playerSheet, 0, 0)
end

video:FrameEnd()
```

### Discovering All Assets at Boot

```lua
local KRNL = require("/KRNL/OS")
local rom = KRNL.GetDriver("ROM")

print("=== ROM Asset Inventory ===")

local sprites = rom:ListSprites()
print(string.format("Sprites (%d):", #sprites))
for _, name in ipairs(sprites) do
    print("  - " .. name)
end

local audioFiles = rom:ListAudio()
print(string.format("Audio (%d):", #audioFiles))
for _, name in ipairs(audioFiles) do
    print("  - " .. name)
end

local assets = rom:ListAssets()
print(string.format("Other Assets (%d):", #assets))
for _, name in ipairs(assets) do
    print("  - " .. name)
end
```

### Preloading All Audio with Fallback

```lua
local KRNL = require("/KRNL/OS")
local rom = KRNL.GetDriver("ROM")
local audio = KRNL.GetDriver("AudioChip0")

local function loadAudioOrFallback(userName, systemName)
    -- Try user asset first, then system fallback
    local sample = rom:GetAudio(userName) or rom:GetSystemAudio(systemName)
    if sample then
        return sample
    end
    return nil
end

local bgm = loadAudioOrFallback("bgm_theme", "DefaultMusic")
local sfxJump = loadAudioOrFallback("sfx_jump", "Jump")
local sfxCoin = loadAudioOrFallback("sfx_coin", "CoinPickup")

-- Note: loadAudioOrFallback will log a warning for the first failed lookup
-- if the user asset doesn't exist, which is expected behavior
```

## Relationship to Other Components

| Component | Relationship |
|---|---|
| **Video Driver** | Primary consumer of sprite sheets and the standard font. Sprite sheets are used for `DrawSprite`, `DrawText`, and as textures in 3D rendering via `VideoTexture.sheet`. |
| **Audio Driver** | Primary consumer of audio samples. Audio samples are passed to `Claim()` / `ClaimAny()` for playback. |
| **Execution Handler** | Can use `Code` assets from the ROM for dynamic script execution via registered file formats. |
| **VFS** | The VFS stores file content separately on Flash Memory, but ROM assets provide bundled read-only resources that don't consume flash storage. |
| **Reality Driver** | The Reality Driver's `LoadSprite()` and `LoadAudio()` load assets from the real filesystem, while the ROM Driver loads bundled gadget assets. They serve complementary purposes. |

---

## User vs System Assets

| Aspect | User Assets | System Assets |
|---|---|---|
| Source | Added in Retro Gadgets editor | Built into Retro Gadgets |
| Persistence | Bundled with the gadget file | Always available |
| Categories | Sprites, Audio, Code, Generic Assets | Sprites, Audio |
| Naming | User-defined names | Predefined system names |
| Retrieval | `GetSprite`, `GetAudio`, `GetCode`, `GetAsset` | `GetSystemSprite`, `GetSystemAudio` |
| Standard Font | Not in User namespace | `GetStandardFont()` or `GetSystemSprite("StandardFont")` |
| Listing | `ListSprites`, `ListAudio`, `ListAssets` | No listing method (system assets are fixed) |

---

## Limitations

* **No search** — Assets can only be retrieved by exact name. There is no pattern matching, partial search, or tag-based lookup.
* **No system listing** — `ListSprites()`, `ListAudio()`, and `ListAssets()` only cover User assets. There is no way to enumerate System assets at runtime.
* **No asset metadata** — Beyond the name, no metadata (author, date, description) is exposed.
