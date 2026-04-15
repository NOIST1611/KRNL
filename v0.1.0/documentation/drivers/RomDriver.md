
---

# 💿 RomDriver Reference

The **RomDriver** provides a structured way to access assets stored within the `ROM` component. It abstracts the complex nesting of the hardware ROM and provides clean methods to retrieve SpriteSheets, AudioSamples, and Code snippets.

---

## 📥 Accessing the Driver

```lua
local KRNL = require("/KRNL/OS")
local rom = KRNL.GetDriver("ROM")

if not rom then
    print("ROM component is missing! No assets can be loaded.")
end
```

---

## 🖼️ Sprite & Visual Assets

### `rom:GetSprite(name: string): SpriteSheet`
Retrieves a SpriteSheet from the **User** section of the ROM.
* **Usage:** Your main game/app textures.
* **Returns:** `SpriteSheet` object (or nil with a log warning if not found).

### `rom:GetSystemSprite(name: string): SpriteSheet`
Retrieves a SpriteSheet from the **System** section.
* **Usage:** Built-in icons, cursors, or OS elements.

### `rom:GetStandardFont(): SpriteSheet`
A shortcut method that returns the default `StandardFont` from the system assets. Useful for `VideoDriver:DrawText()`.

---

## 🔊 Audio Assets

### `rom:GetAudio(name: string): AudioSample`
Retrieves an audio sample from the **User** section.
* **Example:** `speaker:Play(rom:GetAudio("JumpSound"))`

### `rom:GetSystemAudio(name: string): AudioSample`
Retrieves an audio sample from the **System** section. Useful for UI clicks, error beeps, etc.

---

## 📝 Code & Generic Assets

### `rom:GetCode(name: string): Code`
Retrieves a `Code` asset from the User ROM. There's no any usage for this yet.

### `rom:GetAsset(name: string): any`
Retrieves a generic asset from the User `Assets` folder.

---

## 🔍 Discovery & Reflection
These methods are essential for creating file explorers or dynamic asset loaders.

| Method | Return Type | Description |
| :--- | :--- | :--- |
| `rom:ListAssets()` | `{ string }` | Returns a list of all names in User Assets. |
| `rom:ListSprites()` | `{ string }` | Returns a list of all User SpriteSheet names. |
| `rom:ListAudio()` | `{ string }` | Returns a list of all User AudioSample names. |

---

## 💡 Code Example: Dynamic Asset Loader

```lua
local video = KRNL.GetDriver("VideoChip")
local rom = KRNL.GetDriver("ROM")

local sprites = rom:ListSprites()

for i, spriteName in ipairs(sprites) do
    print(string.format("Found sprite [%d]: %s", i, spriteName))
end

-- Load and draw a specific sprite
local mySheet = rom:GetSprite("HeroRun")
video:DrawSprite(10, 10, mySheet, 0, 0, color.white, color.clear)
```

---

## ⚠️ Important Notes

1.  **Safety First:** If an asset is not found, the RomDriver will return `nil` and print a `logWarning` to the system console. This prevents hard crashes but requires you to check if the asset exists.
2.  **Case Sensitivity:** Asset names are case-sensitive. "MySprite" is not the same as "mysprite".
3.  **Namespace Division:**
    * **User:** Content you (the developer) added to the ROM.
    * **System:** Standard assets provided by the RG ROM.

---
