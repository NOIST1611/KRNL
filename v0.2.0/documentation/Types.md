 KRNL v0.2.0 Type Reference

Complete reference of all types exported by the KRNL kernel. These types can be used for Luau type annotations when writing OS code on top of KRNL.

---

## Table of Contents

- [Core Types](#core-types)
- [Signal & Event Types](#signal--event-types)
- [Task Types](#task-types)
- [VFS Types](#vfs-types)
- [Driver Base Types](#driver-base-types)
- [CPU Driver](#cpu-driver)
- [LCD Driver](#lcd-driver)
- [Keyboard Driver](#keyboard-driver)
- [Video Driver](#video-driver)
- [ROM Driver](#rom-driver)
- [LED Driver](#led-driver)
- [LED Button Driver](#led-button-driver)
- [Switch Driver](#switch-driver)
- [Slider Driver](#slider-driver)
- [Reality Driver](#reality-driver)
- [Flash Memory Driver](#flash-memory-driver)
- [Audio Driver](#audio-driver)
- [Wifi Driver](#wifi-driver)
- [NET Types](#net-types)
- [IPC Types](#ipc-types)
- [Execution Handler Types](#execution-handler-types)
- [Kernel Types](#kernel-types)

---

## Core Types

### `DelayedCallback`

A callback scheduled for deferred execution via `CPUDriver.Delay()`.

| Field | Type | Description |
|---|---|---|
| `fn` | `(...any) -> ()` | The function to call when the delay expires. |
| `time` | `number` | The target runtime (in seconds) at which the callback should fire. |
| `args` | `{ [number]: any, n: number }` | Arguments packed for the callback, including the count `n`. |

```lua
local cpu = KRNL.GetDriver("CPU0")
cpu:Delay(function(name, value)
    print(name .. " = " .. tostring(value))
end, 2.0, "ping", 42)
```

### `callback`

A generic function type used throughout the driver system.

```lua
type callback = (...any) -> any
```

---

## Signal & Event Types

### `Signal`

A pub/sub signal object used by drivers to expose hardware events. Signals allow multiple listeners to be attached and automatically manage connection lifecycle.

| Field | Type | Description |
|---|---|---|
| `__index` | `{ any }` | Metatable for method resolution. |
| `_connections` | `{ Connection }` | Active connections (listeners). |
| `_name` | `string` | Internal name of the signal. |
| `_active` | `boolean` | Whether the signal is currently active. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `Fire` | `(self: Signal, ...any) -> ()` | Invokes all connected listeners with the given arguments. |
| `Connect` | `(self: Signal, callback) -> Connection?` | Attaches a new listener. Returns a `Connection` object. |
| `Once` | `(self: Signal, callback) -> Connection?` | Attaches a listener that auto-disconnects after the first `Fire`. |
| `Disable` | `(self: Signal) -> ()` | Disconnects all listeners and deactivates the signal. |

```lua
local keyboard = KRNL.GetDriver("KeyboardChip0")
keyboard.InputBegan:Connect(function(sender, event)
    print("Key pressed: " .. event.key)
end)
```

### `Connection`

Represents an active listener attached to a `Signal`. Used to manage individual subscriptions.

| Field | Type | Description |
|---|---|---|
| `id` | `number` | Unique connection identifier. |
| `_connected` | `boolean` | Whether the connection is still active. |
| `callback` | `callback` | The listener function. |
| `Disconnect` | `(...any) -> ()` | Disconnects this listener from the signal. |

```lua
local conn = keyboard.InputBegan:Connect(myHandler)
-- Later:
conn:Disconnect()
```

---

## Task Types

### `Task`

Represents a running or idle process in the kernel. Created by `KRNL.CreateTask()` or `KRNL.LaunchTask()`.

| Field | Type | Description |
|---|---|---|
| `pid` | `string` | Unique 6-character process identifier (e.g., `"a3f8b1"`). |
| `name` | `string` | Human-readable task name. Defaults to `"unknown_task"`. |
| `data` | `{ [any]: any }` | User-defined data table accessible via `self.data` in the update function. |
| `state` | `"running" \| "idle"` | Current execution state. |
| `Update` | `((self: Task) -> ())?` | Called every tick while the task is `running`. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `SetState` | `(self: Task, state: "running" \| "idle") -> ()` | Changes the task's execution state. |
| `Kill` | `(self: Task, registry: TaskRegistry) -> ()` | Terminates the task and removes it from the registry. |

### `TaskConfig`

Configuration table passed to `KRNL.CreateTask()` and `KRNL.LaunchTask()`.

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | `string?` | No | Task name. Defaults to `"unknown_task"`. |
| `Data` | `{ [any]: any }?` | No | Initial data table for the task. |
| `UpdateFunction` | `((self: Task) -> ())?` | No | Update function called every tick while running. |

### `TaskRegistry`

A table mapping PIDs to Task objects. Returned by `KRNL.GetTasks()`.

```lua
type TaskRegistry = { [string]: Task }

-- Usage:
local tasks: TaskRegistry = KRNL.GetTasks()
for pid: string, task: Task in pairs(tasks) do
    print(pid, task.name, task.state)
end
```

---

## VFS Types

### `VFSInstance`

A Virtual File System instance backed by a FlashMemory component. Provides file and directory management with automatic persistence.

| Field | Type | Description |
|---|---|---|
| `driver` | `any` | The underlying FlashMemory driver. |
| `mounted` | `boolean` | Whether the VFS has been mounted. |
| `root` | `Node` | The root directory node of the file system tree. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `Mount` | `(self) -> boolean` | Mounts the VFS, loading from FlashMemory or creating defaults. |
| `Commit` | `(self) -> boolean` | Persists the current state to FlashMemory. |
| `Write` | `(self, path: string, content: string) -> boolean` | Writes content to a file. |
| `Read` | `(self, path: string) -> string?` | Reads file content. |
| `WriteTable` | `(self, path: string, data: {any}) -> boolean` | Serializes and writes a table. |
| `ReadTable` | `(self, path: string) -> {any}?` | Reads and deserializes a table. |
| `MakeDir` | `(self, path: string) -> boolean` | Creates a directory. |
| `List` | `(self, path: string) -> {string}?` | Lists directory contents. |
| `Remove` | `(self, path: string) -> boolean` | Removes a file or empty directory. |
| `RemoveAll` | `(self, path: string) -> boolean` | Recursively removes a node and all children. |
| `Exists` | `(self, path: string) -> boolean` | Checks if a path exists. |
| `IsFile` | `(self, path: string) -> boolean` | Checks if a path is a file. |
| `IsDir` | `(self, path: string) -> boolean` | Checks if a path is a directory. |
| `Stat` | `(self, path: string) -> Node?` | Returns metadata for a path. |
| `Copy` | `(self, src: string, dst: string) -> boolean` | Copies a file. |
| `Move` | `(self, src: string, dst: string) -> boolean` | Moves or renames a file. |
| `Execute` | `(self, path: string) -> (boolean, string?)` | Executes a file via the Execution Handler. |

### `Node`

A node in the VFS tree. Can represent either a file or a directory.

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Node name. |
| `type` | `NodeType` | `"file"` or `"directory"`. |
| `content` | `string?` | File content. `nil` for directories. |
| `children` | `{ [string]: Node }?` | Child nodes. `nil` for files. |
| `size` | `number` | Content size in bytes. |
| `modified` | `number` | Modification timestamp. |

### `NodeType`

String union type for node classification.

```lua
type NodeType = "file" | "directory"
```

### `VFSRegistry`

A table mapping driver instance names to VFS instances. Used internally by the kernel.

```lua
type VFSRegistry = { [string]: VFSInstance }
```

---

## Driver Base Types

### `Driver`

The base type for all hardware driver wrappers. Every specific driver extends this type.

| Field | Type | Description |
|---|---|---|
| `instance` | `any` | The underlying Retro Gadgets component instance. |
| `_driverData` | `BaseDriverData` | Internal driver metadata. |
| `_update` | `(self: Driver) -> ()` | Called every tick by `KRNL.Update()` to poll hardware state. |

### `BaseDriverData`

Internal metadata shared by all drivers.

| Field | Type | Description |
|---|---|---|
| `instance_name` | `string` | The component instance name (e.g., `"CPU0"`, `"Lcd0"`). |

### `HookableDriver`

A driver that supports event channel hooking. Used by drivers that receive hardware events (Keyboard, Wifi).

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `GetEventFunction` | `(self) -> (sender: any, data: any) -> ()` | Returns the event handler function for the hardware event channel. |

### `DriverRegistry`

A table mapping driver instance names to Driver objects. Used internally by the kernel.

```lua
type DriverRegistry = { [string]: Driver }
```

---

## CPU Driver

### `CPUDriver`

Wraps a CPU chip. Provides timing, runtime info, and delayed callback scheduling.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `CPUDriverData` | CPU-specific driver data. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `GetDeltaTime` | `(self: CPUDriver) -> number` | Returns the time (in seconds) since the last tick. |
| `GetRuntime` | `(self: CPUDriver) -> number` | Returns the total runtime (in seconds) since boot. |
| `GetTPS` | `(self: CPUDriver) -> number` | Returns the current ticks per second. |
| `GetUsage` | `(self: CPUDriver) -> number` | Returns the current CPU usage percentage. |
| `Delay` | `(self: CPUDriver, callback: (...any) -> (), time: number?, ...any) -> ()` | Schedules a callback to fire after `time` seconds. Additional arguments are passed to the callback. |

### `CPUDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `CPUDriverUserdata` | CPU-specific userdata. |

### `CPUDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `dt` | `number` | Delta time from the last tick. |
| `runtime` | `number` | Total runtime in seconds. |
| `delayed_callbacks` | `{ DelayedCallback }` | Queue of pending delayed callbacks. |

```lua
local cpu: CPUDriver = KRNL.GetDriver("CPU0")
print("Runtime: " .. cpu:GetRuntime() .. "s")
print("TPS: " .. cpu:GetTPS())
print("Usage: " .. cpu:GetUsage() .. "%")

cpu:Delay(function()
    print("2 seconds later!")
end, 2.0)
```

---

## LCD Driver

### `LcdDriver`

Wraps an LCD display component. Provides text output and color management.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `LcdDriverData` | LCD-specific driver data. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `SetText` | `(self, text: string) -> ()` | Sets the display text. |
| `GetText` | `(self) -> string` | Returns the current display text. |
| `Clear` | `(self) -> ()` | Clears the display. |
| `PrintLine` | `(self, line: number, text: string) -> ()` | Prints text to a specific line (0-indexed). |
| `CenterLine` | `(self, line: number, text: string) -> ()` | Prints centered text to a specific line. |
| `SetTextColor` | `(self, color: any) -> ()` | Sets the text color. |
| `SetBackgroundColor` | `(self, color: any) -> ()` | Sets the background color. |
| `GetTextColor` | `(self) -> any` | Returns the current text color. |
| `GetBackgroundColor` | `(self) -> any` | Returns the current background color. |

### `LcdDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `LcdDriverUserdata` | LCD-specific userdata. |

### `LcdDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `bg_color` | `any` | Current background color. |
| `text_color` | `any` | Current text color. |

```lua
local lcd: LcdDriver = KRNL.GetDriver("Lcd0")
lcd:SetBackgroundColor(Color4.new(0, 0, 0, 1))
lcd:SetTextColor(Color4.new(255, 255, 255, 1))
lcd:Clear()
lcd:CenterLine(0, "KRNL v0.2.0")
lcd:PrintLine(2, "System Ready")
```

---

## Keyboard Driver

### `KeyboardDriver`

Wraps a Keyboard Chip. Provides key input buffering, held-key tracking, and input event signals.

| Field | Type | Description |
|---|---|---|
| *(inherits all from HookableDriver)* | | |
| `_driverData` | `KeyboardDriverData` | Keyboard-specific driver data. |
| `InputBegan` | `Signal` | Fires when any key is pressed. |
| `InputEnded` | `Signal` | Fires when any key is released. |
| `BufferChanged` | `Signal` | Fires when the input buffer changes. |
| `BufferSubmit` | `Signal` | Fires when the buffer is submitted (Enter pressed). |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `GetBuffer` | `(self) -> string` | Returns the current input buffer contents. |
| `Flush` | `(self) -> ()` | Clears the input buffer. |
| `IsKeyHeld` | `(self, key: string) -> boolean` | Returns `true` if a key is currently held down. |
| `SetBufferLimit` | `(self, limit: number) -> ()` | Sets the maximum number of characters in the buffer. |
| `HookEventChannel` | `(self) -> (sender: any, event: any) -> ()` | Returns the event handler for hardware event channel hooking. |

### `KeyboardDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `KeyboardDriverUserdata` | Keyboard-specific userdata. |

### `KeyboardDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `buffer` | `string` | Current text buffer. |
| `held_keys` | `{ [string]: boolean }` | Currently held keys. |
| `buffer_limit` | `number` | Maximum buffer length. |
| `event_function` | `(sender: any, event: any) -> ()` | Internal event handler. |

```lua
local kb: KeyboardDriver = KRNL.GetDriver("KeyboardChip0")

kb.InputBegan:Connect(function(sender, event)
    print("Key: " .. event.key)
end)

kb.BufferSubmit:Connect(function(sender, event)
    local input = kb:GetBuffer()
    print("Input: " .. input)
    kb:Flush()
end)

kb:SetBufferLimit(32)
```

---

## Video Driver

### `VideoDriver`

Wraps a Video Chip. Provides 2D drawing, 3D rendering with custom shaders, touch input, and texture management.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `Math3D` | `any` | Built-in 3D math utility library. |
| `_driverData` | `VideoDriverData` | Video-specific driver data. |
| `OnTouchBegin` | `Signal` | Fires when touch starts. |
| `OnTouchEnd` | `Signal` | Fires when touch ends. |
| `OnTouchPositionChange` | `Signal` | Fires when touch position changes. |

#### Frame Methods

| Method | Signature | Description |
|---|---|---|
| `GetSize` | `(self) -> (number, number)` | Returns `(width, height)` of the video buffer. |
| `SetTargetBuffer` | `(self, index: number) -> ()` | Sets the active render buffer index. |
| `SetBufferSize` | `(self, index: number, w: number, h: number) -> ()` | Sets the size of a render buffer. |
| `FrameStart` | `(self) -> ()` | Begins a new frame. Call before drawing. |
| `FrameEnd` | `(self) -> ()` | Ends the current frame and submits draw calls. |

#### Shader Methods

| Method | Signature | Description |
|---|---|---|
| `SetVertexShader` | `(self, fn: any) -> ()` | Sets a custom vertex shader function. |
| `SetFragmentShader` | `(self, fn: any) -> ()` | Sets a custom fragment shader function. |
| `SetUniform` | `(self, key: string, value: any) -> ()` | Sets a shader uniform value. |
| `GetUniform` | `(self, key: string) -> any` | Gets a shader uniform value. |
| `UseDefaultVertexShader` | `(self) -> ()` | Resets to the default vertex shader. |
| `UseDefaultFragmentShader` | `(self, flat_color: any?) -> ()` | Resets to the default fragment shader with optional flat color. |
| `UseLambertShader` | `(self, light_dir: any?, base_color: any?) -> ()` | Uses Lambert lighting model with optional light direction and base color. |

#### Camera & Transform Methods

| Method | Signature | Description |
|---|---|---|
| `SetCamera` | `(self, eye: any, center: any, up: any, fov: number?) -> ()` | Sets the view camera with position, target, up vector, and optional FOV. |
| `SetClipPlanes` | `(self, near: number, far: number) -> ()` | Sets the near and far clip planes. |
| `SetTransform` | `(self, pos: any, rot: any, scale: any) -> ()` | Sets position, rotation, and scale. |
| `SetModelMatrix` | `(self, mat: any) -> ()` | Directly sets the model matrix. |

#### 3D Drawing Methods

| Method | Signature | Description |
|---|---|---|
| `DrawTri3D` | `(self, v1, v2, v3) -> ()` | Draws a 3D triangle. |
| `DrawTri3DTextured` | `(self, v1, v2, v3, tex: VideoTexture) -> ()` | Draws a textured 3D triangle. |
| `DrawQuad3D` | `(self, v1, v2, v3, v4) -> ()` | Draws a 3D quad. |
| `DrawQuad3DTextured` | `(self, v1, v2, v3, v4, tex: VideoTexture) -> ()` | Draws a textured 3D quad. |
| `DrawMesh` | `(self, mesh: any) -> ()` | Draws a 3D mesh. |
| `DrawMeshTextured` | `(self, mesh: any, default_tex: VideoTexture?) -> ()` | Draws a textured 3D mesh. |

#### 2D Drawing Methods

| Method | Signature | Description |
|---|---|---|
| `Clear` | `(self, col: any) -> ()` | Clears the buffer with a color. |
| `SetPixel` | `(self, x: number, y: number, col: any) -> ()` | Sets a single pixel. |
| `DrawLine` | `(self, x1, y1, x2, y2, col: any) -> ()` | Draws a line. |
| `DrawRect` | `(self, x1, y1, x2, y2, col: any) -> ()` | Draws a rectangle outline. |
| `FillRect` | `(self, x1, y1, x2, y2, col: any) -> ()` | Draws a filled rectangle. |
| `DrawCircle` | `(self, x, y, r, col: any) -> ()` | Draws a circle outline. |
| `FillCircle` | `(self, x, y, r, col: any) -> ()` | Draws a filled circle. |
| `DrawTriangle` | `(self, x1, y1, x2, y2, x3, y3, col: any) -> ()` | Draws a triangle outline. |
| `FillTriangle` | `(self, x1, y1, x2, y2, x3, y3, col: any) -> ()` | Draws a filled triangle. |
| `DrawText` | `(self, x, y, font: any, text: string, tc: any, bc: any) -> ()` | Draws text at a position. |
| `DrawSprite` | `(self, x, y, sheet, sx, sy, tint, bg) -> ()` | Draws a sprite from a sprite sheet. |
| `DrawPointGrid` | `(self, ox, oy, dist, col: any) -> ()` | Draws a grid of points. |

#### Touch Methods

| Method | Signature | Description |
|---|---|---|
| `GetTouchState` | `(self) -> boolean` | Returns whether the screen is being touched. |
| `IsTouchDown` | `(self) -> boolean` | Returns `true` on the tick touch started. |
| `IsTouchUp` | `(self) -> boolean` | Returns `true` on the tick touch ended. |
| `GetTouchPosition` | `(self) -> (number, number)` | Returns `(x, y)` touch position. |

### `VideoTexture`

Represents a texture for 3D rendering, referencing a region of a sprite sheet.

| Field | Type | Description |
|---|---|---|
| `sheet` | `any` | The sprite sheet asset. |
| `sx` | `number?` | Sprite X index. |
| `sy` | `number?` | Sprite Y index. |
| `offset` | `any?` | UV offset. |
| `size` | `any?` | UV size. |
| `tint` | `any?` | Color tint. |
| `bg` | `any?` | Background color. |

### `VideoTriQueued`

Internal queued triangle data for the rendering pipeline.

| Field | Type | Description |
|---|---|---|
| `sx1`, `sy1`, `sx2`, `sy2`, `sx3`, `sy3`, `sx4`, `sy4` | `number` | Screen-space vertex coordinates. Quad uses 4 vertices, triangle uses 3. |
| `nx`, `ny`, `nz` | `number` | World-space normal vector. |
| `depth` | `number` | Depth value for sorting. |
| `texture` | `VideoTexture?` | Optional texture. |
| `is_quad` | `boolean` | Whether this is a quad (4 vertices) or triangle (3 vertices). |

### `VideoDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `VideoDriverUserdata` | Video-specific userdata. |

### `VideoDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `touch_state` | `boolean` | Current touch state. |
| `touch_position` | `{ x: number, y: number }` | Last known touch position. |
| `target_buffer` | `number` | Active render buffer index. |
| `buffer_active` | `boolean` | Whether a buffer is active. |
| `width` | `number` | Buffer width in pixels. |
| `height` | `number` | Buffer height in pixels. |
| `camera` | `any` | Camera configuration. |
| `proj_matrix` | `any` | Projection matrix. |
| `view_matrix` | `any` | View matrix. |
| `model_matrix` | `any` | Model matrix. |
| `mvp_matrix` | `any` | Combined model-view-projection matrix. |
| `vertex_shader` | `((world_pos, uniforms) -> (number?, number?, number?))?` | Custom vertex shader function. |
| `fragment_shader` | `((tri, uniforms) -> any)?` | Custom fragment shader function. |
| `uniforms` | `{ [string]: any }` | Shader uniform values. |
| `tri_queue` | `{ VideoTriQueued }` | Queue of triangles/quads to render. |

```lua
local video: VideoDriver = KRNL.GetDriver("VideoChip0")
local w, h = video:GetSize()

video:FrameStart()
video:Clear(Color4.new(0, 0, 0, 1))

-- 2D drawing
video:FillRect(10, 10, 100, 50, Color4.new(255, 0, 0, 1))
video:DrawText(10, 60, rom:GetStandardFont(), "Hello!", Color4.new(255, 255, 255, 1), nil)

-- 3D rendering
video:UseLambertShader({ x = 0, y = -1, z = 0 })
video:SetCamera({ x = 0, y = 2, z = 5 }, { x = 0, y = 0, z = 0 }, { x = 0, y = 1, z = 0 })

video:FrameEnd()
```

---

## ROM Driver

### `RomDriver`

Wraps a ROM chip. Provides access to sprites, audio, fonts, code snippets, and other embedded assets.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `RomDriverData` | ROM-specific driver data. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `GetSprite` | `(self, name: string) -> any` | Returns a sprite asset by name. |
| `GetSystemSprite` | `(self, name: string) -> any` | Returns a system-reserved sprite by name. |
| `GetStandardFont` | `(self) -> any` | Returns the standard font asset. |
| `GetAudio` | `(self, name: string) -> any` | Returns an audio asset by name. |
| `GetSystemAudio` | `(self, name: string) -> any` | Returns a system-reserved audio asset by name. |
| `GetCode` | `(self, name: string) -> any` | Returns a code snippet asset by name. |
| `GetAsset` | `(self, name: string) -> any` | Returns any asset by name. |
| `ListAssets` | `(self) -> { string }` | Lists all asset names in the ROM. |
| `ListSprites` | `(self) -> { string }` | Lists all sprite names. |
| `ListAudio` | `(self) -> { string }` | Lists all audio names. |

### `RomDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `{}` | Empty userdata (reserved for future use). |

```lua
local rom: RomDriver = KRNL.GetDriver("ROM0")
local font = rom:GetStandardFont()
local playerSprite = rom:GetSprite("player")

local assets = rom:ListAssets()
for _, name in ipairs(assets) do
    print("Asset: " .. name)
end
```

---

## LED Driver

### `LedDriver`

Wraps an LED component. Provides color and on/off state control.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `LedDriverData` | LED-specific driver data. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `SetColor` | `(self, clr: any) -> ()` | Sets the LED color. |
| `GetColor` | `(self) -> any` | Returns the current LED color. |
| `SetState` | `(self, state: boolean) -> ()` | Turns the LED on (`true`) or off (`false`). |
| `GetState` | `(self) -> boolean` | Returns `true` if the LED is on. |

### `LedDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `LedDriverUserdata` | LED-specific userdata. |

### `LedDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `led_color` | `any` | Current LED color. |
| `state` | `boolean` | Current on/off state. |

```lua
local led: LedDriver = KRNL.GetDriver("Led0")
led:SetColor(Color4.new(0, 255, 0, 1))
led:SetState(true)
```

---

## LED Button Driver

### `LedButtonDriver`

Wraps an LED Button component. Combines button input detection with LED control.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `LedButtonDriverData` | LED Button-specific driver data. |
| `OnPressed` | `Signal` | Fires when the button is pressed. |
| `OnReleased` | `Signal` | Fires when the button is released. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `SetColor` | `(self, clr: any) -> ()` | Sets the LED color. |
| `GetColor` | `(self) -> any` | Returns the current LED color. |
| `SetLedState` | `(self, state: boolean) -> ()` | Controls the LED on/off. |
| `GetLedState` | `(self) -> boolean` | Returns `true` if the LED is on. |
| `IsPressed` | `(self) -> boolean` | Returns `true` if the button is currently pressed. |

### `LedButtonDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `LedButtonDriverUserdata` | LED Button-specific userdata. |

### `LedButtonDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `led_color` | `any` | Current LED color. |
| `led_state` | `boolean` | Current LED state. |
| `event_function` | `(sender: any, event: any) -> ()` | Internal event handler. |

```lua
local btn: LedButtonDriver = KRNL.GetDriver("LedButton0")
btn:SetColor(Color4.new(0, 0, 255, 1))

btn.OnPressed:Connect(function()
    print("Button pressed!")
    btn:SetLedState(true)
end)

btn.OnReleased:Connect(function()
    btn:SetLedState(false)
end)
```

---

## Switch Driver

### `SwitchDriver`

Wraps a Switch component. Provides toggle state tracking with change signals.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `SwitchDriverData` | Switch-specific driver data. |
| `StateChanged` | `Signal` | Fires when the switch position changes. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `SetState` | `(self, state: boolean) -> ()` | Sets the switch position programmatically. |
| `GetState` | `(self) -> boolean` | Returns the current switch position. |

### `SwitchDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `SwitchDriverUserdata` | Switch-specific userdata. |

### `SwitchDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `state` | `boolean` | Current switch state. |

```lua
local sw: SwitchDriver = KRNL.GetDriver("Switch0")
sw.StateChanged:Connect(function()
    print("Switch: " .. tostring(sw:GetState()))
end)
```

---

## Slider Driver

### `SliderDriver`

Wraps a Slider component. Provides analog value tracking with change signals.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `SliderDriverData` | Slider-specific driver data. |
| `ValueChanged` | `Signal` | Fires when the slider value changes. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `SetValue` | `(self, value: number) -> ()` | Sets the slider value programmatically. |
| `GetValue` | `(self) -> number` | Returns the current slider value. |
| `IsMoving` | `(self) -> boolean` | Returns `true` if the slider is being actively moved. |

### `SliderDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `SliderDriverUserdata` | Slider-specific userdata. |

### `SliderDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `value` | `number` | Current slider value. |

```lua
local slider: SliderDriver = KRNL.GetDriver("Slider0")
slider.ValueChanged:Connect(function()
    print("Volume: " .. math.floor(slider.GetValue() * 100) .. "%")
end)
```

---

## Reality Driver

### `RealityDriver`

Wraps a Reality Chip. Provides access to real-world system information including CPU, RAM, network, date/time, and file I/O.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `RealityDriverData` | Reality-specific driver data. |

#### System Info Methods

| Method | Signature | Description |
|---|---|---|
| `GetCPUUsage` | `(self) -> number` | Returns overall CPU usage (0-1). |
| `GetCPUCoresUsage` | `(self) -> { number }` | Returns per-core CPU usage array. |
| `GetRAMAvailable` | `(self) -> number` | Returns available RAM in bytes. |
| `GetRAMUsed` | `(self) -> number` | Returns used RAM in bytes. |
| `GetRAMTotal` | `(self) -> number` | Returns total RAM in bytes. |
| `GetNetworkSent` | `(self) -> number` | Returns total network bytes sent. |
| `GetNetworkReceived` | `(self) -> number` | Returns total network bytes received. |

#### Date & Time Methods

| Method | Signature | Description |
|---|---|---|
| `GetDateTime` | `(self) -> RealityDateTime` | Returns local date and time. |
| `GetDateTimeUTC` | `(self) -> RealityDateTime` | Returns UTC date and time. |
| `GetTimeString` | `(self) -> string` | Returns formatted time string. |
| `GetDateString` | `(self) -> string` | Returns formatted date string. |

#### Asset Methods

| Method | Signature | Description |
|---|---|---|
| `LoadSprite` | `(self, filename: string, sw: number, sh: number) -> any` | Loads a sprite from the real filesystem. |
| `LoadAudio` | `(self, filename: string) -> any` | Loads audio from the real filesystem. |
| `UnloadAsset` | `(self, filename: string) -> ()` | Unloads a previously loaded asset. |
| `ListDir` | `(self, directory: string) -> { string }` | Lists directory contents. |
| `GetFileMeta` | `(self, filename: string) -> any` | Gets file metadata. |

### `RealityDateTime`

| Field | Type | Description |
|---|---|---|
| `year` | `number` | Year (e.g., 2026). |
| `month` | `number` | Month (1-12). |
| `day` | `number` | Day of month (1-31). |
| `yday` | `number` | Day of year (1-366). |
| `wday` | `number` | Day of week (1-7, Sunday = 1). |
| `hour` | `number` | Hour (0-23). |
| `min` | `number` | Minute (0-59). |
| `sec` | `number` | Second (0-59). |
| `isdst` | `boolean` | Whether daylight saving time is active. |

### `RealityDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `RealityDriverUserdata` | Empty userdata (reserved). |

```lua
local reality: RealityDriver = KRNL.GetDriver("RealityChip0")
print("CPU: " .. math.floor(reality:GetCPUUsage() * 100) .. "%")
print("RAM: " .. math.floor(reality:GetRAMUsed() / 1024) .. " KB")
print("Time: " .. reality:GetTimeString())
print("Date: " .. reality:GetDateString())
```

---

## Flash Memory Driver

### `FlashMemoryDriver`

Wraps a Flash Memory component. Provides persistent data storage used by VFS.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `FlashMemoryDriverData` | Flash Memory-specific driver data. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `GetUsage` | `(self) -> (number, string, number)` | Returns `(used_bytes, formatted_string, used_percentage)`. |
| `GetSize` | `(self) -> (number, string)` | Returns `(total_bytes, formatted_string)`. |
| `Save` | `(self, data: {any}) -> boolean` | Saves data to flash memory. Returns `false` if capacity exceeded. |
| `Load` | `(self) -> {any}` | Loads data from flash memory. Returns empty table if no data stored. |

### `FlashMemoryDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | No additional fields. |

```lua
local flash: FlashMemoryDriver = KRNL.GetDriver("FlashMemory0")
local used, usedStr, usedPct = flash:GetUsage()
local total, totalStr = flash:GetSize()
print(string.format("Storage: %s / %s (%.1f%%)", usedStr, totalStr, usedPct))
```

---

## Audio Driver

### `AudioDriver`

Wraps an Audio Chip. Provides multi-channel audio playback with volume/pitch control, spectrum analysis, and playback state tracking.

| Field | Type | Description |
|---|---|---|
| *(inherits all from Driver)* | | |
| `_driverData` | `AudioDriverData` | Audio-specific driver data. |
| `ChannelStarted` | `Signal` | Fires when a channel starts playing. |
| `ChannelFinished` | `Signal` | Fires when a channel finishes playing. |
| `ChannelStopped` | `Signal` | Fires when a channel is stopped. |
| `ChannelLooped` | `Signal` | Fires when a channel loops. |

#### Channel Management

| Method | Signature | Description |
|---|---|---|
| `Claim` | `(self, ChannelID: number, Audio: any, Settings: AudioChannelSettings?) -> boolean` | Claims a specific channel for an audio asset. |
| `ClaimAny` | `(self, Audio: any, Settings: AudioChannelSettings?) -> number?` | Claims the first available channel. Returns channel ID or `nil`. |
| `Free` | `(self, ChannelID: number, Force: boolean?) -> boolean` | Frees a channel. `Force` immediately stops playback. |
| `IsClaimed` | `(self, ChannelID: number) -> boolean` | Returns `true` if a channel is claimed. |
| `GetClaimedChannels` | `(self) -> { number }` | Returns list of claimed channel IDs. |

#### Playback Control

| Method | Signature | Description |
|---|---|---|
| `Play` | `(self, ChannelID: number, StartTime: number?) -> boolean` | Plays audio on a channel from optional start time. |
| `PlayRelative` | `(self, ChannelID: number, Delay: number) -> boolean` | Plays audio after a delay (in seconds). |
| `PlayLoop` | `(self, ChannelID: number, StartTime: number?) -> boolean` | Plays audio in a loop. |
| `Stop` | `(self, ChannelID: number) -> boolean` | Stops playback on a channel. |
| `Pause` | `(self, ChannelID: number) -> boolean` | Pauses playback. |
| `UnPause` | `(self, ChannelID: number) -> boolean` | Resumes paused playback. |
| `IsPlaying` | `(self, ChannelID: number) -> boolean` | Returns `true` if audio is playing. |
| `IsPaused` | `(self, ChannelID: number) -> boolean` | Returns `true` if audio is paused. |
| `GetPlayTime` | `(self, ChannelID: number) -> number` | Returns current playback position in seconds. |
| `SeekPlayTime` | `(self, ChannelID: number, Time: number) -> boolean` | Seeks to a specific playback position. |

#### Volume & Pitch

| Method | Signature | Description |
|---|---|---|
| `SetMasterVolume` | `(self, Volume: number) -> ()` | Sets global volume (0-1). |
| `GetMasterVolume` | `(self) -> number` | Returns global volume. |
| `SetMasterPitch` | `(self, Pitch: number) -> ()` | Sets global pitch multiplier (1.0 = normal). |
| `GetMasterPitch` | `(self) -> number` | Returns global pitch. |
| `SetVolume` | `(self, ChannelID: number, Volume: number) -> boolean` | Sets per-channel volume. |
| `GetVolume` | `(self, ChannelID: number) -> number` | Returns per-channel volume. |
| `SetPitch` | `(self, ChannelID: number, Pitch: number) -> boolean` | Sets per-channel pitch. |
| `GetPitch` | `(self, ChannelID: number) -> number` | Returns per-channel pitch. |

#### Analysis

| Method | Signature | Description |
|---|---|---|
| `GetDSPTime` | `(self) -> number` | Returns the DSP processing time. |
| `GetSpectrumData` | `(self, ChannelID: number, BandsCount: number?) -> { number }` | Returns frequency spectrum data for a channel. |
| `GetLevel` | `(self, ChannelID: number) -> number` | Returns the current audio level (RMS) for a channel. |
| `GetMasterSpectrumData` | `(self, BandsCount: number?) -> { number }` | Returns frequency spectrum for the master output. |
| `GetMasterLevel` | `(self) -> number` | Returns the master output audio level. |

### `AudioChannelSettings`

Configuration for channel behavior.

| Field | Type | Description |
|---|---|---|
| `AutoFree` | `boolean?` | Automatically free the channel when playback finishes. |
| `Priority` | `number?` | Channel priority for `ClaimAny` selection. |

### `AudioChannelEntry`

Internal record of a claimed channel.

| Field | Type | Description |
|---|---|---|
| `Audio` | `any` | The audio asset assigned to the channel. |
| `Settings` | `AudioChannelSettings` | Channel settings. |
| `IsLoop` | `boolean` | Whether the channel is set to loop. |

### `AudioChannelState`

Runtime state of a channel.

| Field | Type | Description |
|---|---|---|
| `playing` | `boolean` | Whether the channel is currently playing. |
| `playtime` | `number` | Current playback position. |

### `AudioDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `AudioDriverUserdata` | Audio-specific userdata. |

### `AudioDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `ClaimedChannels` | `{ [number]: AudioChannelEntry }` | All claimed channels. |
| `ChannelStates` | `{ [number]: AudioChannelState }` | Runtime state per channel. |
| `MasterVolume` | `number` | Global volume (0-1). |
| `MasterPitch` | `number` | Global pitch multiplier. |

```lua
local audio: AudioDriver = KRNL.GetDriver("AudioChip0")
local rom: RomDriver = KRNL.GetDriver("ROM0")

local bgm = rom:GetAudio("background_music")
local ch = audio:ClaimAny(bgm, { AutoFree = false, Priority = 10 })
if ch then
    audio:PlayLoop(ch)
    audio:SetVolume(ch, 0.5)
end

local sfx = rom:GetAudio("click_sfx")
local sfxCh = audio:ClaimAny(sfx, { AutoFree = true })
if sfxCh then
    audio:Play(sfxCh)
end
```

---

## Wifi Driver

### `WifiDriver`

Wraps a Wifi chip. Provides low-level HTTP request methods, audio streaming, and cookie management. This driver is used internally by the NET module.

| Field | Type | Description |
|---|---|---|
| *(inherits all from HookableDriver)* | | |
| `_driverData` | `WifiDriverData` | Wifi-specific driver data. |
| `OnResponse` | `Signal` | Fires when a response is received. |
| `OnError` | `Signal` | Fires when a request fails. |
| `OnProgress` | `Signal` | Fires on upload/download progress. |

#### Availability & Hooking

| Method | Signature | Description |
|---|---|---|
| `IsAvailable` | `(self) -> boolean` | Returns `true` if the Wifi chip is accessible. |
| `HookEventChannel` | `(self) -> (sender: any, event: any) -> ()` | Returns the event handler for hardware event hooking. |

#### HTTP Methods

| Method | Signature | Description |
|---|---|---|
| `Get` | `(self, url: string, callback?) -> number?` | HTTP GET request. |
| `Post` | `(self, url: string, body: string, callback?) -> number?` | HTTP POST with raw body. |
| `PostJSON` | `(self, url: string, data: {any}, callback?) -> number?` | HTTP POST with JSON body. |
| `PostForm` | `(self, url: string, form: {[string]: string}, callback?) -> number?` | HTTP POST with form data. |
| `Put` | `(self, url: string, body: string, callback?) -> number?` | HTTP PUT request. |
| `Delete` | `(self, url: string, callback?) -> number?` | HTTP DELETE request. |
| `Request` | `(self, url, method, headers, contentType, body, callback?) -> number?` | Generic HTTP request. |
| `StreamAudio` | `(self, url: string, callback?) -> number?` | Streams audio from a URL. |

#### Request Management

| Method | Signature | Description |
|---|---|---|
| `Abort` | `(self, handle: number) -> boolean` | Aborts a request by handle. |
| `GetUploadProgress` | `(self, handle: number) -> number` | Returns upload progress (0-1). |
| `GetDownloadProgress` | `(self, handle: number) -> number` | Returns download progress (0-1). |
| `IsPending` | `(self, handle: number) -> boolean` | Returns `true` if request is in-flight. |
| `GetPendingCount` | `(self) -> number` | Returns the number of pending requests. |

#### Cookies

| Method | Signature | Description |
|---|---|---|
| `ClearCookies` | `(self) -> ()` | Clears all cookies. |
| `ClearCookiesFor` | `(self, url: string) -> ()` | Clears cookies for a specific URL. |

### `WifiDriverData`

| Field | Type | Description |
|---|---|---|
| *(inherits from BaseDriverData)* | | |
| `userdata` | `WifiDriverUserdata` | Wifi-specific userdata. |

### `WifiDriverUserdata`

| Field | Type | Description |
|---|---|---|
| `send_buffer` | `{ any }` | Outgoing data buffer. |
| `receive_buffer` | `{ any }` | Incoming data buffer. |
| `send_buffer_size` | `number` | Send buffer capacity. |
| `receive_buffer_size` | `number` | Receive buffer capacity. |
| `event_function` | `(sender: any, event: any) -> ()` | Internal event handler. |
| `pending` | `{ [number]: any }` | Pending request handles. |

> **Note:** In most cases, use `NET` (via `KRNL.GetPrimaryNET()`) instead of the Wifi driver directly. NET provides queuing, retries, caching, interceptors, and JSON helpers on top of the raw Wifi API.

---

## NET Types

### `NETInstance`

High-level HTTP client instance created by the kernel for each Wifi component. Provides a full-featured networking API.

| Method | Signature | Description |
|---|---|---|
| `SetBaseURL` | `(self, url: string) -> ()` | Sets base URL for relative paths. |
| `SetDefaultHeader` | `(self, key: string, value: string) -> ()` | Sets a global default header. |
| `SetTimeout` | `(self, seconds: number) -> ()` | Sets default timeout. |
| `SetRetries` | `(self, count: number, delay: number?) -> ()` | Sets default retry count and delay. |
| `SetMaxConcurrent` | `(self, count: number) -> ()` | Sets max simultaneous requests. |
| `UseRequestInterceptor` | `(self, fn) -> NETInstance` | Adds a request interceptor. |
| `UseResponseInterceptor` | `(self, fn) -> NETInstance` | Adds a response interceptor. |
| `Get` | `(self, url, callback, options?) -> ()` | HTTP GET. |
| `Post` | `(self, url, body, callback, options?) -> ()` | HTTP POST. |
| `PostJSON` | `(self, url, data, callback, options?) -> ()` | HTTP POST with JSON. |
| `PostForm` | `(self, url, form, callback, options?) -> ()` | HTTP POST with form data. |
| `Put` | `(self, url, body, callback, options?) -> ()` | HTTP PUT. |
| `PutJSON` | `(self, url, data, callback, options?) -> ()` | HTTP PUT with JSON. |
| `Delete` | `(self, url, callback, options?) -> ()` | HTTP DELETE. |
| `Patch` | `(self, url, body, callback, options?) -> ()` | HTTP PATCH. |
| `PatchJSON` | `(self, url, data, callback, options?) -> ()` | HTTP PATCH with JSON. |
| `Request` | `(self, options) -> ()` | Generic request. |
| `StreamAudio` | `(self, url, callback) -> number?` | Stream audio. |
| `GetDownloadProgress` | `(self, handle: number) -> number` | Download progress (0-1). |
| `GetUploadProgress` | `(self, handle: number) -> number` | Upload progress (0-1). |
| `IsPending` | `(self, handle: number) -> boolean` | Check if request is active. |
| `Abort` | `(self, handle: number) -> boolean` | Abort a request. |
| `AbortAll` | `(self) -> ()` | Abort all requests. |
| `ClearCache` | `(self) -> ()` | Clear all cached responses. |
| `ClearCacheFor` | `(self, url, method?) -> ()` | Clear cache for specific URL. |
| `SetCacheEnabled` | `(self, enabled: boolean) -> ()` | Enable/disable caching. |
| `SetCacheTTL` | `(self, seconds: number) -> ()` | Set cache TTL. |
| `ClearCookies` | `(self) -> ()` | Clear all cookies. |
| `ClearCookiesFor` | `(self, url: string) -> ()` | Clear cookies for URL. |
| `GetStats` | `(self) -> NETStats` | Get diagnostic stats. |
| `_update` | `(self) -> ()` | Internal update (called by kernel). |

### `NETConfig`

Configuration for NET instances, set via `Config.NETConfig`.

| Field | Type | Default | Description |
|---|---|---|---|
| `base_url` | `string?` | `""` | Base URL for relative paths. |
| `timeout` | `number?` | `30` | Default timeout in seconds. |
| `retries` | `number?` | `0` | Default retry count. |
| `retry_delay` | `number?` | `1` | Delay between retries. |
| `max_concurrent` | `number?` | `4` | Max simultaneous requests. |
| `default_headers` | `{ [string]: string }?` | `{}` | Default headers. |
| `cache_enabled` | `boolean?` | `false` | Enable response caching. |
| `cache_ttl` | `number?` | `60` | Cache TTL in seconds. |

### `NETResponse`

Response object passed to all HTTP callbacks.

| Field | Type | Description |
|---|---|---|
| `ok` | `boolean` | Whether the request succeeded. |
| `status` | `number` | HTTP status code. |
| `url` | `string` | Final URL. |
| `method` | `string` | HTTP method used. |
| `text` | `string?` | Response body as text. |
| `json` | `any?` | Auto-parsed JSON body (if Content-Type is JSON). |
| `data` | `string?` | Raw response data. |
| `pixelData` | `any?` | Pixel data (image responses). |
| `audioSample` | `any?` | Audio sample data. |
| `contentType` | `string` | Content-Type header. |
| `handle` | `number` | Request handle. |
| `error` | `{ type: string, message: string }?` | Error info if request failed. |
| `cached` | `boolean` | Whether served from cache. |
| `elapsed` | `number` | Request duration in seconds. |

### `NETStats`

Diagnostic information returned by `NET:GetStats()`.

| Field | Type | Description |
|---|---|---|
| `active` | `number` | Currently in-flight requests. |
| `queued` | `number` | Requests waiting in queue. |
| `cached` | `number` | Cached responses. |
| `available` | `boolean` | Wifi availability. |
| `runtime` | `number` | Current CPU runtime. |

---

## IPC Types

### `IPCInterface`

The Inter-Process Communication event bus.

| Method | Signature | Description |
|---|---|---|
| `Listen` | `(event: string, callback, options: IPCOptions) -> ()` | Subscribe to events. |
| `Post` | `(event: string, data: any) -> ()` | Publish an event. |
| `Cleanup` | `(taskID: string) -> ()` | Remove all listeners for a task. |
| `GetSubscriptionCount` | `() -> number` | Returns total active listeners. |

### `IPCOptions`

Options for `IPC.Listen()`.

| Field | Type | Default | Description |
|---|---|---|---|
| `priority` | `number?` | `100` | Dispatch priority (lower = first). |
| `once` | `boolean?` | `false` | Auto-remove after first invocation. |
| `taskID` | `string` | (required) | Owning task identifier. |

### `Listener`

Internal record of a single event subscription.

| Field | Type | Description |
|---|---|---|
| `callback` | `(data: any, event: string) -> ()` | The listener function. |
| `priority` | `number` | Dispatch priority. |
| `taskID` | `string` | Owning task identifier. |
| `once` | `boolean` | Whether to auto-remove after firing. |

### `IPCRegistry`

Internal table mapping event patterns to arrays of listeners.

```lua
type IPCRegistry = { [string]: {Listener} }
```

---

## Execution Handler Types

### `ExecutionInterface`

The file execution handler registry.

| Method | Signature | Description |
|---|---|---|
| `RegisterFormat` | `(extension, handler, mode?, config?, task_config?) -> ()` | Register a file format handler. |
| `GetTaskConfig` | `(extension: string) -> TaskConfig?` | Get default task config for a format. |
| `GetMode` | `(extension: string) -> string?` | Get execution mode (`"sync"` or `"async"`). |
| `GetHandler` | `(extension: string) -> any?` | Get the handler function. |
| `GetConfig` | `(extension: string) -> {[string]: any}?` | Get format-specific config. |
| `HasFormat` | `(extension: string) -> boolean` | Check if format is registered. |
| `GetFormats` | `() -> { string }` | List all registered formats. |
| `Execute` | `(path: string, content: string) -> (boolean, string?)` | Execute file content directly. |

### `ExecutionMode`

Union type for execution modes.

```lua
type ExecutionMode = "sync" | "async"
```

### `FormatData`

Internal record for a registered file format.

| Field | Type | Description |
|---|---|---|
| `handler` | `(content: string, path: string, config) -> (boolean, string?)` | The handler function. |
| `mode` | `ExecutionMode` | Execution mode. |
| `config` | `{ [string]: any }` | Format-specific configuration. |
| `task_config` | `TaskConfig` | Default task configuration for async mode. |

---

## Kernel Types

### `KernelSingleton`

The internal kernel instance returned by `Core.Boot()`. Manages all tasks, drivers, VFS instances, and NET instances.

| Field | Type | Description |
|---|---|---|
| `tasks` | `TaskRegistry` | All registered tasks. |
| `drivers` | `DriverRegistry` | All loaded hardware drivers. |
| `_flags` | `KernelFlags` | Internal kernel state flags. |
| `vfs` | `VFSRegistry` | All VFS instances. |
| `net` | `{ [string]: NETInstance }` | All NET instances. |

#### Methods

| Method | Signature | Description |
|---|---|---|
| `CreateTask` | `(self, task_config: TaskConfig) -> Task` | Creates a new task. |
| `KillTask` | `(self, pid: string) -> ()` | Kills a task by PID. |
| `GetDriver` | `(self, name: string) -> Driver?` | Gets a driver by instance name. |
| `GetUtility` | `(self, name: string) -> any` | Gets a utility module. |
| `GetVFS` | `(self, name: string) -> VFSInstance?` | Gets a VFS instance by name. |
| `GetPrimaryVFS` | `(self) -> VFSInstance?` | Gets the primary VFS instance. |
| `GetNET` | `(self, name: string) -> NETInstance?` | Gets a NET instance by name. |
| `GetPrimaryNET` | `(self) -> NETInstance?` | Gets the primary NET instance. |
| `GetTasks` | `(self) -> { [string]: Task }` | Returns the task registry. |

### `KernelFlags`

Internal flags tracking kernel initialization state.

| Field | Type | Description |
|---|---|---|
| `_driversLoaded` | `boolean` | Whether hardware drivers have been loaded. |
| `_vfsAvailable` | `boolean` | Whether at least one VFS was mounted. |
| `_netAvailable` | `boolean` | Whether at least one NET instance was created. |
