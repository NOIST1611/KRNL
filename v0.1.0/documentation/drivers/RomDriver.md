
---

# RomDriver Reference

The **RomDriver** provides a structured way to access assets stored within the Gadget.

---

## Accessing the Driver

```lua
local KRNL = require("/KRNL/OS")
local rom = KRNL.GetDriver("ROM")

if not rom then
    print("ROM component is missing")
end
```

---

## Sprite & Visual Assets

### `rom:GetSprite(name: string): SpriteSheet`
Retrieves a SpriteSheet from the **Gadget**.
* **Usage:** Your main game/app textures.
* **Returns:** `SpriteSheet` object (or nil if not found).

### `rom:GetSystemSprite(name: string): SpriteSheet`
Retrieves a SpriteSheet from the **Retro gadgets** built-in assets.
* **Usage:** Built-in assets.

### `rom:GetStandardFont(): SpriteSheet`
A shortcut method that returns the default `StandardFont` from the system assets. Useful for `VideoDriver:DrawText()`.

---

## Audio Assets

### `rom:GetAudio(name: string): AudioSample`
Retrieves an audio sample from the **Gadget**.

### `rom:GetSystemAudio(name: string): AudioSample`
Retrieves an audio sample from the **Retro gadgets** built-in assets.

---

## Code & Generic Assets

### `rom:GetCode(name: string): Code`
Retrieves a `Code` asset from the Gadget.

### `rom:GetAsset(name: string): any`
Retrieves a generic asset from the Gadget `Assets` folder.

---

## Discovery & Reflection
Methods to get host files of file system

| Method | Return Type | Description |
| :--- | :--- | :--- |
| `rom:ListAssets()` | `{ string }` | Returns a list of all names in User Assets. |
| `rom:ListSprites()` | `{ string }` | Returns a list of all User SpriteSheet names. |
| `rom:ListAudio()` | `{ string }` | Returns a list of all User AudioSample names. |

---

## Code Example: Dynamic Asset Loader

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
