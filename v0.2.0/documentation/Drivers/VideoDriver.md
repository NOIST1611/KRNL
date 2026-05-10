# Video Driver

The **Video Driver** wraps a Retro Gadgets `VideoChip` component and provides a comprehensive 2D/3D rendering pipeline with custom shaders, camera management, depth-sorted triangle queue, multi-buffer support, touch input tracking, and direct hardware drawing wrappers. It is the most feature-rich driver in the KRNL driver ecosystem.

---

## Overview

The Video Chip is Retro Gadgets' primary graphics output device. The Video Driver builds on top of it by introducing a managed rendering pipeline: frame begin/end lifecycle, a deferred triangle queue with depth sorting (painter's algorithm), pluggable vertex and fragment shaders, and a full matrix-based 3D math system via `Math3D`. For simpler 2D drawing needs, all hardware-level drawing methods are exposed as thin one-liner wrappers.

**Key features:**

* **Frame lifecycle** — `FrameStart()` / `FrameEnd()` pairs manage render buffer state and triangle queue flushing.
* **3D rendering pipeline** — Vertex shaders project 3D world coordinates to screen space; a deferred triangle queue with back-face culling and depth sorting (painter's algorithm) handles draw order.
* **Fragment shaders** — Customizable per-triangle coloring, including a built-in Lambert lighting model.
* **Camera system** — Perspective camera with configurable eye position, target, up vector, FOV, and near/far clip planes.
* **Model transforms** — Position, rotation, and scale via a model matrix that feeds into the MVP pipeline.
* **Multi-buffer support** — Switch between render buffers and set per-buffer dimensions.
* **2D drawing** — Full set of immediate-mode 2D primitives (pixels, lines, rects, circles, triangles, text, sprites, point grids).
* **Touch input** — Three signals (`OnTouchBegin`, `OnTouchEnd`, `OnTouchPositionChange`) with state change detection per tick.
* **Math3D integration** — The `Math3D` utility library is exposed directly as `VideoDriver.Math3D`.

---

## Accessing the Video Driver

```lua
local KRNL = require("/KRNL/OS")

-- By instance name
local video = KRNL.GetDriver("VideoChip0")

-- Access the Math3D library directly
local Math3D = video.Math3D
```

---

## Rendering Pipeline Overview

The Video Driver uses a deferred rendering approach for 3D geometry. Instead of drawing triangles immediately, they are queued, sorted by depth, and flushed at `FrameEnd()`. 2D drawing calls go directly to the hardware.

```
FrameStart()
  ├─ Activate render buffer
  ├─ Clear to black
  └─ Reset triangle queue
        │
        ▼
  Draw Calls (3D)
  ├─ Vertex shader: world_pos → screen (x, y, depth)
  ├─ Back-face culling (cross product test)
  ├─ Normal computation
  └─ Enqueue to tri_queue
        │
  Draw Calls (2D)
  └─ Direct hardware draw (immediate)
        │
        ▼
FrameEnd()
  ├─ Sort tri_queue by depth (far → near, painter's algorithm)
  ├─ For each triangle:
  │  ├─ Textured? → RasterSprite / RasterCustomSprite
  │  └─ Untextured? → fragment_shader → FillTriangle
  └─ Blit render buffer to screen
```

---

## Internal Constants & Defaults

| Constant / Default | Value | Description |
|---|---|---|
| `Prefix` | `"[VIDEOCHIP DRIVER]:"` | Log message prefix. |
| Default camera `eye` | `vec3(0, 0, -5)` | Camera starts 5 units back on the Z axis. |
| Default camera `center` | `vec3(0, 0, 0)` | Camera looks at the origin. |
| Default camera `up` | `vec3(0, 1, 0)` | Standard Y-up orientation. |
| Default camera `fov` | `60` | 60-degree vertical field of view. |
| Default camera `near` | `0.1` | Near clip plane distance. |
| Default camera `far` | `1000` | Far clip plane distance. |
| Default `target_buffer` | `1` | First render buffer. |
| Default `buffer_active` | `false` | No frame in progress at boot. |

---

## API Reference

### Static Methods

#### `Video.AddDriver(instance: VideoChip, name: string, registry: DriverRegistry): VideoDriver?`

Static factory method. Creates a new Video driver and registers it in the driver registry. Called internally by the kernel during boot.

* **instance**: The Retro Gadgets `VideoChip` component instance.
* **name**: The driver instance name (e.g., `"VideoChip0"`).
* **registry**: The kernel's driver registry table.
* **Returns**: A new `VideoDriver` instance, or `nil` if the component type is invalid.

**Initialization:**

1. Validates `instance.Type == "VideoChip"`.
2. Creates the driver via `setmetatable({}, Video)`.
3. Stores `instance` reference and exposes `Math3D` as `Driver.Math3D`.
4. Initializes all userdata fields (camera, matrices, shaders, uniforms, touch state, buffer state).
5. Builds the initial perspective projection matrix from the chip's native `Width / Height`.
6. Creates three touch signals via `BetterEvents.new()`.

---

#### `Video.GetDriver(name: string, registry: DriverRegistry): VideoDriver?`

Static lookup method. Retrieves a previously registered Video driver from the registry.

* **name**: The driver instance name.
* **registry**: The kernel's driver registry table.
* **Returns**: The `VideoDriver` instance, or `nil` if not found.

---

### Frame Management

#### `video:SetTargetBuffer(index: number): ()`

Sets the active render buffer index. All frame operations will target this buffer. If a frame is currently active (`buffer_active == true`), immediately switches the hardware to render on the new buffer.

* **index**: The render buffer index (1-based). Clamped to the number of available buffers if out of range.

```lua
video:SetTargetBuffer(2)  -- Switch to the second render buffer
```

---

#### `video:SetBufferSize(index: number, w: number, h: number): ()`

Sets the dimensions of a specific render buffer and rebuilds the projection matrix with the new aspect ratio.

* **index**: The render buffer index.
* **w**: New width in pixels.
* **h**: New height in pixels.

After resizing, the projection matrix is recalculated using `w / h` as the aspect ratio and the current camera's FOV and clip planes. The MVP matrix is also rebuilt.

```lua
video:SetBufferSize(1, 320, 240)
```

---

#### `video:GetSize(): (number, number)`

Returns the current logical width and height of the target buffer.

* **Returns**: `width, height` in pixels.

```lua
local w, h = video:GetSize()
print(string.format("Resolution: %dx%d", w, h))
```

---

#### `video:FrameStart(): ()`

Begins a new render frame. Must be called before any drawing operations.

**Behavior:**

1. If a frame is already active (`buffer_active == true`), returns immediately (no-op).
2. Sets `buffer_active = true`.
3. Clears the triangle queue (`tri_queue = {}`).
4. Switches the hardware to render on the target buffer via `RenderOnBuffer()`.
5. Clears the buffer to black.

> **Important:** Every `FrameStart()` must be paired with a `FrameEnd()`. Calling drawing functions outside of a frame pair produces undefined behavior.

```lua
video:FrameStart()
-- ... drawing calls ...
video:FrameEnd()
```

---

#### `video:FrameEnd(): ()`

Ends the current render frame, flushes the 3D triangle queue, and blits the result to the screen.

**Behavior:**

1. If no frame is active (`buffer_active == false`), returns immediately (no-op).
2. Calls `_flushTriQueue()` to process all queued 3D triangles.
3. Sets `buffer_active = false`.
4. Switches hardware to screen rendering via `RenderOnScreen()`.
5. Clears the screen to black.
6. Draws the render buffer to the screen at position `(0, 0)` with the configured width and height.

---

### Shader System

#### `video:SetVertexShader(fn): ()`

Sets a custom vertex shader function. The vertex shader is responsible for transforming 3D world coordinates into 2D screen coordinates.

* **fn**: A function with signature `(world_pos: vec3, uniforms: { [string]: any }) -> (number?, number?, number?)`.
  * **world_pos**: The 3D vertex position.
  * **uniforms**: The current uniform values table.
  * **Returns**: `screen_x, screen_y, depth` — or `nil` to discard the vertex (off-screen clipping).

```lua
video:SetVertexShader(function(world_pos, uniforms)
    -- Simple orthographic projection
    return world_pos.x, world_pos.y, world_pos.z
end)
```

---

#### `video:SetFragmentShader(fn): ()`

Sets a custom fragment shader function. The fragment shader determines the color of each triangle during the queue flush.

* **fn**: A function with signature `(tri: table, uniforms: { [string]: any }) -> color`.
  * **tri**: The queued triangle data (contains `nx`, `ny`, `nz` for the normal, `depth`, `sx*`/`sy*` for screen coords).
  * **uniforms**: The current uniform values table.
  * **Returns**: A `color` value to fill the triangle with.

```lua
video:SetFragmentShader(function(tri, uniforms)
    -- Depth-based fog effect
    local fog = math.max(0, 1 - tri.depth / 10)
    return ColorRGBA(math.floor(100 * fog), math.floor(150 * fog), math.floor(255 * fog), 255)
end)
```

---

#### `video:SetUniform(key: string, value: any): ()`

Sets a shader uniform value. Uniforms are passed to both the vertex and fragment shaders on every draw call.

* **key**: The uniform name.
* **value**: Any value (number, vec3, color, table, etc.).

```lua
video:SetUniform("time", cpu:GetRuntime())
video:SetUniform("color", color.red)
```

---

#### `video:GetUniform(key: string): any`

Returns the current value of a shader uniform.

* **key**: The uniform name.
* **Returns**: The uniform value, or `nil` if not set.

```lua
local t = video:GetUniform("time")
```

---

#### `video:UseDefaultVertexShader(): ()`

Resets the vertex shader to the built-in default. This shader applies the full MVP (Model-View-Projection) pipeline:

1. Transforms `world_pos` by the MVP matrix: `clip = mvp * world_pos`.
2. If `clip.W == 0` or `clip.W < 0`, the vertex is behind the camera — returns `nil` (culled).
3. Converts the clip-space position to screen coordinates via `Math3D.vec4_to_screen()`.
4. Returns `screen_x, screen_y, clip.Z / clip.W` (depth as NDC Z).

```lua
video:UseDefaultVertexShader()
```

---

#### `video:UseDefaultFragmentShader(flat_color?): ()`

Resets the fragment shader to a simple flat-color shader.

* **flat_color**: *(Optional)* The color to use. Defaults to `color.white`.

Every triangle will be filled with this solid color, ignoring normals, depth, and lighting.

```lua
video:UseDefaultFragmentShader(color.red)
video:UseDefaultFragmentShader()  -- white
```

---

#### `video:UseLambertShader(light_dir?, base_color?): ()`

Sets the fragment shader to a Lambert (diffuse) lighting model. This provides basic directional lighting where surface brightness depends on the angle between the surface normal and the light direction.

* **light_dir**: *(Optional)* Light direction as a `vec3`. Defaults to `vec3(0.5, 1, 0.5)` (normalized internally).
* **base_color**: *(Optional)* Base material color. Defaults to `color.white`.

**Lighting formula:**

```
normalized_normal = normalize(tri.nx, tri.ny, tri.nz)
normalized_light  = normalize(light_dir)
NdotL             = max(0, dot(normal, light_dir))
intensity         = clamp(0.15 + NdotL, 0, 1)
result            = base_color * intensity
```

The ambient term is hardcoded at `0.15`, ensuring that even surfaces facing away from the light retain 15% brightness.

```lua
-- Warm light from above-right
video:UseLambertShader(vec3(1, 1, 0.5), ColorRGBA(200, 180, 160, 255))

-- Cool light from directly above
video:UseLambertShader(vec3(0, -1, 0), color.blue)
```

---

### Camera & Transforms

#### `video:SetCamera(eye: vec3, center: vec3, up: vec3, fov?: number): ()`

Configures the view camera. Rebuilds the view matrix, projection matrix, and MVP matrix.

* **eye**: Camera position in world space.
* **center**: Point the camera looks at.
* **up**: Camera up direction vector.
* **fov**: *(Optional)* Vertical field of view in degrees. If `nil`, the previous FOV is retained.

The view matrix is built via `Math3D.mat4_look_at(eye, center, up)`. The projection matrix uses the current aspect ratio (`width / height`), the specified (or existing) FOV, and the current near/far clip planes.

```lua
-- First-person camera
video:SetCamera(
    vec3(0, 2, -5),   -- eye: slightly elevated, looking from the front
    vec3(0, 0, 0),    -- center: looking at origin
    vec3(0, 1, 0),    -- up: standard Y-up
    75                 -- 75-degree FOV (wider view)
)

-- Top-down camera
video:SetCamera(
    vec3(0, 10, 0),   -- eye: directly above
    vec3(0, 0, 0),    -- center: looking down at origin
    vec3(0, 0, -1),   -- up: -Z is "up" on screen
    60
)
```

---

#### `video:SetClipPlanes(near: number, far: number): ()`

Sets the near and far clipping plane distances. Rebuilds the projection and MVP matrices.

* **near**: Near clip plane distance (must be > 0).
* **far**: Far clip plane distance (must be > near).

Objects closer than `near` or farther than `far` from the camera will be clipped by the vertex shader.

```lua
video:SetClipPlanes(0.5, 500)
```

---

#### `video:SetTransform(pos: vec3, rot: vec3, scale?: vec3): ()`

Sets the model transform using position, rotation, and scale. Builds a model matrix via `Math3D.mat4_model_matrix()` and rebuilds the MVP matrix.

* **pos**: Translation in world space.
* **rot**: Rotation in radians (Euler angles: X, Y, Z).
* **scale**: *(Optional)* Scale factors. Defaults to `vec3(1, 1, 1)` (no scale).

```lua
-- Place a cube at (2, 0, 0), rotated 45 degrees on Y, at double size
video:SetTransform(vec3(2, 0, 0), vec3(0, Math3D:radians(45), 0), vec3(2, 2, 2))
```

---

#### `video:SetModelMatrix(mat): ()`

Directly sets the model matrix, bypassing the `SetTransform()` convenience method. Rebuilds the MVP matrix.

* **mat**: A 4x4 matrix (as created by `Math3D` functions).

Use this when you need custom model matrices (e.g., for hierarchical transforms, bone animations).

```lua
local mat = Math3D:mat4()
-- ... apply custom transformations to mat ...
video:SetModelMatrix(mat)
```

---

### 3D Drawing Methods

All 3D drawing methods enqueue triangles into the internal `tri_queue`. They are NOT drawn immediately — the queue is flushed during `FrameEnd()`. Every 3D draw call requires an active vertex shader.

**Common behavior:**

* If no vertex shader is set, a warning is logged and the call is ignored.
* If the vertex shader returns `nil` for any vertex, the entire primitive is discarded (frustum clipping).
* Back-face culling is applied: primitives facing away from the camera (negative screen-space cross product) are silently discarded.

#### `video:DrawTri3D(v1: vec3, v2: vec3, v3: vec3): ()`

Enqueues an untextured 3D triangle defined by three world-space vertices.

* **v1, v2, v3**: Triangle vertices in world space.

```lua
video:SetTransform(vec3(0, 0, 0), vec3(0, 0, 0))
video:DrawTri3D(vec3(-1, -1, 0), vec3(1, -1, 0), vec3(0, 1, 0))
```

---

#### `video:DrawTri3DTextured(v1: vec3, v2: vec3, v3: vec3, texture): ()`

Enqueues a textured 3D triangle. The texture is a `VideoTexture` table with sprite sheet information.

* **v1, v2, v3**: Triangle vertices in world space.
* **texture**: A texture descriptor table (see [VideoTexture](#videotexture-format)).

```lua
local myTexture = {
    sheet = spriteSheet,
    sx = 0, sy = 0,
    tint = color.white,
    bg = color.clear,
}

video:DrawTri3DTextured(vec3(-1,-1,0), vec3(1,-1,0), vec3(0,1,0), myTexture)
```

---

#### `video:DrawQuad3D(v1: vec3, v2: vec3, v3: vec3, v4: vec3): ()`

Enqueues an untextured 3D quad defined by four vertices. Internally delegates to `DrawQuad3DTextured` with `nil` texture.

* **v1, v2, v3, v4**: Quad vertices in world space (clockwise or counter-clockwise winding).

```lua
video:DrawQuad3D(
    vec3(-1, -1, 0), vec3(1, -1, 0),
    vec3(1, 1, 0),   vec3(-1, 1, 0)
)
```

---

#### `video:DrawQuad3DTextured(v1: vec3, v2: vec3, v3: vec3, v4: vec3, texture): ()`

Enqueues a textured 3D quad.

* **v1, v2, v3, v4**: Quad vertices in world space.
* **texture**: A texture descriptor table (or `nil` for untextured).

Depth is calculated as the average of all four vertex depths. During flushing, quads are split into two triangles for rendering.

```lua
video:DrawQuad3DTextured(
    vec3(-1, -1, 0), vec3(1, -1, 0),
    vec3(1, 1, 0),   vec3(-1, 1, 0),
    { sheet = mySheet, sx = 0, sy = 0, tint = color.white, bg = color.clear }
)
```

---

#### `video:DrawMesh(mesh): ()`

Draws a mesh composed of multiple untextured triangles. The mesh is a table of triangles, where each triangle is an array of three `vec3` vertices.

* **mesh**: A table in the format `{ {v1, v2, v3}, {v4, v5, v6}, ... }`.

```lua
local pyramid = {
    { vec3(0, 1, 0),    vec3(-1, -1, 1),  vec3(1, -1, 1) },
    { vec3(0, 1, 0),    vec3(1, -1, 1),   vec3(1, -1, -1) },
    { vec3(0, 1, 0),    vec3(1, -1, -1),  vec3(-1, -1, -1) },
    { vec3(0, 1, 0),    vec3(-1, -1, -1), vec3(-1, -1, 1) },
    { vec3(-1,-1, 1),   vec3(1, -1, 1),   vec3(1, -1, -1) },
    { vec3(-1,-1, 1),   vec3(1, -1, -1),  vec3(-1, -1, -1) },
}

video:DrawMesh(pyramid)
```

---

#### `video:DrawMeshTextured(mesh, default_texture?): ()`

Draws a mesh with optional per-triangle textures. Each triangle entry may include a fourth element as its texture. If a triangle has no texture, `default_texture` is used.

* **mesh**: A table of triangles. Each entry: `{v1, v2, v3}` or `{v1, v2, v3, texture}`.
* **default_texture**: *(Optional)* Fallback texture for triangles without their own texture.

```lua
local mesh = {
    { vec3(0,1,0), vec3(-1,-1,1), vec3(1,-1,1), frontTexture },
    { vec3(0,1,0), vec3(1,-1,1), vec3(1,-1,-1), sideTexture },
    { vec3(0,1,0), vec3(1,-1,-1), vec3(-1,-1,-1) }, -- no texture
}

video:DrawMeshTextured(mesh, fallbackTexture)
```

---

### Internal: `_flushTriQueue()`

Called automatically by `FrameEnd()`. Processes all triangles in the queue:

1. **Sorts** the queue by depth in descending order (farthest first) — painter's algorithm.
2. For each triangle:
   * **Textured** — Uses `RasterSprite` (sprite index mode) or `RasterCustomSprite` (UV offset/size mode) depending on whether the texture has `offset` and `size` fields.
   * **Untextured** — Runs the fragment shader (if set, otherwise `color.white`) to determine the fill color. Quads are split into two triangles via `FillTriangle`.

**Depth sort direction:** `a.depth > b.depth` means triangles farthest from the camera are drawn first, with closer triangles overwriting them — this is the standard painter's algorithm.

**Back-face culling at draw time:** Quads and triangles that passed the cross-product test during enqueue are guaranteed to be front-facing in screen space.

---

### Internal: `_rebuildMVP(data)`

Rebuilds the combined Model-View-Projection matrix from the current projection, view, and model matrices:

```
MVP = proj_matrix * (view_matrix * model_matrix)
```

Called automatically whenever the camera, clip planes, or model transform change.

---

### 2D Drawing Methods

These are thin wrappers around the hardware `VideoChip` methods. They draw immediately to the current render target (buffer or screen). They do NOT go through the triangle queue.

> **Note:** 2D drawing calls should be made between `FrameStart()` and `FrameEnd()` to render to the off-screen buffer, which is then blitted to the screen. Drawing outside of a frame pair targets the screen directly.

#### `video:Clear(col: color): ()`

Clears the entire buffer/screen with the specified color.

#### `video:SetPixel(x: number, y: number, col: color): ()`

Sets a single pixel at the given coordinates.

#### `video:DrawLine(x1, y1, x2, y2, col): ()`

Draws a line from `(x1, y1)` to `(x2, y2)`.

#### `video:DrawRect(x1, y1, x2, y2, col): ()`

Draws a rectangle outline with corners at `(x1, y1)` and `(x2, y2)`.

#### `video:FillRect(x1, y1, x2, y2, col): ()`

Draws a filled rectangle.

#### `video:DrawCircle(x, y, r, col): ()`

Draws a circle outline centered at `(x, y)` with radius `r`.

#### `video:FillCircle(x, y, r, col): ()`

Draws a filled circle.

#### `video:DrawTriangle(x1, y1, x2, y2, x3, y3, col): ()`

Draws a triangle outline.

#### `video:FillTriangle(x1, y1, x2, y2, x3, y3, col): ()`

Draws a filled triangle.

#### `video:DrawText(x, y, font, text: string, tc: color, bc: color?): ()`

Draws text at position `(x, y)` using the specified font asset.

* **font**: A font asset from the ROM driver (`rom:GetStandardFont()` or `rom:GetSprite("font")`).
* **text**: The text string to render.
* **tc**: Text (foreground) color.
* **bc**: *(Optional)* Background color. `nil` or `color.clear` for transparent background.

#### `video:DrawSprite(x, y, sheet, sx, sy, tint?, bg?): ()`

Draws a sprite from a sprite sheet at position `(x, y)`.

* **sheet**: The sprite sheet asset.
* **sx**: Sprite X index on the sheet.
* **sy**: Sprite Y index on the sheet.
* **tint**: *(Optional)* Tint color. Defaults to `color.white`.
* **bg**: *(Optional)* Background color. Defaults to `color.clear`.

#### `video:DrawPointGrid(ox, oy, dist, col): ()`

Draws a grid of evenly-spaced points.

* **ox, oy**: Origin offset.
* **dist**: Distance between grid points.
* **col**: Point color.

```lua
video:FrameStart()
video:Clear(color.black)
video:DrawPointGrid(0, 0, 10, ColorRGBA(40, 40, 40, 255))
video:DrawText(10, 10, font, "Hello!", color.white, nil)
video:FrameEnd()
```

---

### Touch Input

The Video Chip supports touch input. The driver tracks touch state across ticks and fires signals on state transitions.

#### Touch Signals

| Signal | Fired When | Arguments |
|---|---|---|
| `OnTouchBegin` | Touch state transitions from not-touched to touched. | `(x: number, y: number)` — Touch position when touch started. |
| `OnTouchEnd` | Touch state transitions from touched to not-touched. | `(x: number, y: number)` — Last known position before touch ended. |
| `OnTouchPositionChange` | Touch position changes while touching. | `(x: number, y: number)` — New touch position. |

#### `video:GetTouchState(): boolean`

Returns whether the screen is currently being touched.

* **Returns**: `true` if touched, `false` otherwise.

---

#### `video:IsTouchDown(): boolean`

Returns `true` only on the tick the touch started (transition from not-touched to touched). This is a one-shot edge detection, not a level check.

* **Returns**: `true` on the touch-down tick, `false` otherwise.

---

#### `video:IsTouchUp(): boolean`

Returns `true` only on the tick the touch ended (transition from touched to not-touched). One-shot edge detection.

* **Returns**: `true` on the touch-up tick, `false` otherwise.

---

#### `video:GetTouchPosition(): (number, number)`

Returns the current touch position.

* **Returns**: `x, y` coordinates in pixels.

```lua
local tx, ty = video:GetTouchPosition()
print(string.format("Touch: %d, %d", tx, ty))
```

---

### Internal Update Loop

The `_update()` method is called automatically by `KRNL.Update()` every tick. It processes touch input state:

```
_update() flow:
  ├─ Read current touch_state and touch_position
  ├─ Compare with previous tick's state:
  │  ├─ State changed to touched → Fire OnTouchBegin(x, y)
  │  └─ State changed to released → Fire OnTouchEnd(old_x, old_y)
  ├─ If touching and position changed → Fire OnTouchPositionChange(x, y)
  └─ Store current state for next tick comparison
```

The state comparison ensures that signals fire exactly once per transition, preventing duplicate events.

---

## VideoTexture Format

Texture descriptors are plain tables passed to `DrawTri3DTextured` / `DrawQuad3DTextured`. They support two modes:

### Sprite Index Mode

Uses `sx` and `sy` to reference a specific sprite cell on a sheet.

| Field | Type | Description |
|---|---|---|
| `sheet` | `any` | Sprite sheet asset (from ROM). |
| `sx` | `number?` | Sprite column index. Defaults to `0`. |
| `sy` | `number?` | Sprite row index. Defaults to `0`. |
| `tint` | `color?` | Tint color applied to the sprite. Defaults to `color.white`. |
| `bg` | `color?` | Background color. Defaults to `color.clear`. |

### UV Offset Mode

Uses `offset` and `size` for sub-sprite UV mapping via `RasterCustomSprite`.

| Field | Type | Description |
|---|---|---|
| `sheet` | `any` | Sprite sheet asset. |
| `offset` | `any` | UV offset (vec2 or table with `x`, `y`). |
| `size` | `any` | UV size (vec2 or table with `x`, `y`). |
| `tint` | `color?` | Tint color. Defaults to `color.white`. |
| `bg` | `color?` | Background color. Defaults to `color.clear`. |

If both `offset` and `size` are present, UV offset mode is used. Otherwise, sprite index mode is used.

```lua
-- Sprite index mode
local tex1 = { sheet = sheet, sx = 2, sy = 1, tint = color.white, bg = color.clear }

-- UV offset mode
local tex2 = { sheet = sheet, offset = { x = 0.25, y = 0 }, size = { x = 0.25, y = 0.5 } }
```

---

## Back-Face Culling

All 3D primitives undergo back-face culling before being enqueued. The test uses the 2D screen-space cross product of the first two edge vectors:

```
cross = (sx2 - sx1) * (sy3 - sy1) - (sy2 - sy1) * (sx3 - sx1)

if cross <= 0 → discard (back-facing)
if cross >  0 → enqueue (front-facing)
```

This ensures that only triangles facing the camera are rendered, which improves both performance and visual correctness. Winding order matters — vertices should be specified in counter-clockwise order when viewed from the front.

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Invalid component type in `AddDriver` | Logs warning, returns `nil`. |
| Driver not found in `GetDriver` | Logs warning, returns `nil`. |
| Buffer index out of range | Logs warning, clamps to max buffer count. |
| No vertex shader set on 3D draw | Logs warning, draw call ignored. |
| Vertex shader returns `nil` (off-screen) | Entire primitive discarded. |
| Back-face culling fails (cross product <= 0) | Primitive silently discarded. |
| `FrameStart()` called while frame active | No-op (ignored). |
| `FrameEnd()` called without active frame | No-op (ignored). |
| Empty triangle queue at `FrameEnd()` | No sorting or drawing occurs. |

---

## Code Examples

### Basic 3D Rotating Cube

```lua
-- Dependencies
local KRNL     = require("/KRNL/OS")
local video    = KRNL.GetDriver("VideoChip0")
local cpu      = KRNL.GetDriver("CPU0")
local MeshGen  = require("/MeshGenerator") -- Assume you have your own Mesh generator

local Math3D = video.Math3D

-- Basic Setup
local W, H = video:GetSize()
video:SetBufferSize(1, W, H)
video:SetTargetBuffer(1)

local CAM_EYE = vec3(0, 2, -5)
video:SetCamera(CAM_EYE, vec3(0, 0, 0), vec3(0, 1, 0), 60)
video:UseDefaultVertexShader()

-- Shaders

local function SetPhongShader(light_dir, base_color, shininess)
    light_dir  = Math3D:vec3_normalize(light_dir  or vec3(1, 2, 1))
    base_color = base_color or color.white
    shininess  = shininess  or 48
		
    local view_dir = Math3D:vec3_normalize(CAM_EYE)
		
    local hx = light_dir.X + view_dir.X
    local hy = light_dir.Y + view_dir.Y
    local hz = light_dir.Z + view_dir.Z
    local half_dir = Math3D:vec3_normalize(vec3(hx, hy, hz))

    video:SetFragmentShader(function(tri, uniforms)
        local n = Math3D:vec3_normalize(vec3(tri.nx, tri.ny, tri.nz))

        local ndotl = math.max(0, Math3D:vec3_dot(n, light_dir))
        local ndoth = math.max(0, Math3D:vec3_dot(n, half_dir))

        local ambient  = 0.07
        local diffuse  = ndotl * 0.82
        local specular = (ndoth ^ shininess) * 0.65   -- белый блик поверх цвета

        local intensity = ambient + diffuse

        return ColorRGBA(
            math.min(255, math.floor(base_color.R * intensity + 255 * specular)),
            math.min(255, math.floor(base_color.G * intensity + 255 * specular)),
            math.min(255, math.floor(base_color.B * intensity + 255 * specular)),
            255
        )
    end)
end

local function SetCelShader(light_dir, base_color, steps)
    light_dir  = Math3D:vec3_normalize(light_dir or vec3(1, 2, 1))
    base_color = base_color or color.white
    steps      = steps or 4

    video:SetFragmentShader(function(tri, uniforms)
        local n = Math3D:vec3_normalize(vec3(tri.nx, tri.ny, tri.nz))

        local ndotl = math.max(0, Math3D:vec3_dot(n, light_dir))

        -- Квантизация: floor(ndotl * steps) / steps  дискретные ступени
        local quantized = math.floor(ndotl * steps) / steps
        local intensity = 0.12 + quantized * 0.88

        return ColorRGBA(
            math.floor(base_color.R * intensity),
            math.floor(base_color.G * intensity),
            math.floor(base_color.B * intensity),
            255
        )
    end)
end

local function SetRimShader(light_dir, base_color, rim_color, rim_power)
    light_dir  = Math3D:vec3_normalize(light_dir or vec3(1, 2, 1))
    base_color = base_color or color.white
    rim_color  = rim_color  or ColorRGBA(80, 180, 255, 255)
    rim_power  = rim_power  or 3

    local view_dir = Math3D:vec3_normalize(CAM_EYE)

    video:SetFragmentShader(function(tri, uniforms)
        local n = Math3D:vec3_normalize(vec3(tri.nx, tri.ny, tri.nz))

        local ndotl = math.max(0, Math3D:vec3_dot(n, light_dir))
        local ndotv = math.max(0, Math3D:vec3_dot(n, view_dir))
				
        local rim = (1 - ndotv) ^ rim_power

        local ambient  = 0.08
        local diffuse  = ndotl * 0.80
        local intensity = ambient + diffuse

        return ColorRGBA(
            math.min(255, math.floor(base_color.R * intensity + rim_color.r * rim)),
            math.min(255, math.floor(base_color.G * intensity + rim_color.g * rim)),
            math.min(255, math.floor(base_color.B * intensity + rim_color.b * rim)),
            255
        )
    end)
end

-- Shader Selection

SetPhongShader(vec3(1, 2, 1), color.white, 1)
--SetCelShader(vec3(1, 2, 1), ColorRGBA(255, 0, 0, 255), 8)
--SetRimShader(vec3(1, 2, 1), ColorRGBA(50, 50, 60, 255), ColorRGBA(200, 200, 255, 255), 4)

-- Cube Mesh
local cube = MeshGen.Sphere(1, 20, 20) -- Your Mesh here

-- Task
KRNL.LaunchTask({
    name = "rotating_cube",
    UpdateFunction = function(task)
        local t     = cpu:GetRuntime()
        local angle = t * 60

        video:FrameStart()
        video:Clear(color.black)
        video:SetTransform(
            vec3(0, 0, 0),
            vec3(angle, angle * 0.7, 0),
            vec3(1, 1, 1)
        )
        video:DrawMesh(cube)
        video:FrameEnd()
    end
})

function update()
    KRNL.Update()
end
```

### 2D UI Overlay with Text

```lua
local KRNL = require("/KRNL/OS")

local video = KRNL.GetDriver("VideoChip0")
local rom = KRNL.GetDriver("ROM")

local W,H = video:GetSize()
video:SetTargetBuffer(1)
video:SetBufferSize(1,W,H)

local font = rom:GetStandardFont()

KRNL.LaunchTask({
    name = "ui_overlay",
    UpdateFunction = function(self)
        video:FrameStart()
        video:Clear(ColorRGBA(20, 20, 30, 255))

        -- Draw a panel background
        video:FillRect(0, 10, 200, 60, ColorRGBA(40, 40, 60, 255))
        video:DrawRect(0, 10, 200, 60, ColorRGBA(100, 100, 150, 255))

        -- Draw text
        video:DrawText(20, 25, font, "KRNL v0.2.0", color.white, color.clear)
        video:DrawText(20, 45, font, "System Online", ColorRGBA(0, 255, 100, 255), color.clear)

        -- Draw a status dot
        video:FillCircle(180, 30, 5, ColorRGBA(0, 255, 0, 255))

        video:FrameEnd()
    end
})

function update()
		KRNL.Update()
end
```

### Touch Input Buttons

```lua
local KRNL = require("/KRNL/OS")
local video = KRNL.GetDriver("VideoChip0")
local rom = KRNL.GetDriver("ROM")
local cpu = KRNL.GetDriver("CPU0")

local W,H = video:GetSize()
video:SetTargetBuffer(1)
video:SetBufferSize(1,W,H)

local font = rom:GetStandardFont()

local buttons = {
    { x = 10, y = 10, w = 80, h = 30, label = "Button A", color = ColorRGBA(60, 120, 200, 255) },
    { x = 100, y = 10, w = 80, h = 30, label = "Button B", color = ColorRGBA(200, 60, 60, 255) },
}

video.OnTouchBegin:Connect(function(tx, ty)
    for _, btn in ipairs(buttons) do
        if tx >= btn.x and tx <= btn.x + btn.w
        and ty >= btn.y and ty <= btn.y + btn.h then
            print(btn.label .. " pressed!")
            btn.color = ColorRGBA(255, 255, 100, 255)
            cpu:Delay(function()
                btn.color = ColorRGBA(60, 120, 200, 255)
            end, 0.2)
        end
    end
end)

KRNL.LaunchTask({
    name = "touch_ui",
    UpdateFunction = function(self)
        video:FrameStart()
        video:Clear(ColorRGBA(30, 30, 40, 255))

        for _, btn in ipairs(buttons) do
            video:FillRect(btn.x, btn.y, btn.x + btn.w, btn.y + btn.h, btn.color)
            video:DrawText(btn.x + 5, btn.y + 8, font, btn.label, color.white, color.clear)
        end

        video:FrameEnd()
    end
})

function update()
		KRNL.Update()
end
```

---

## Relationship to Other Components

| Component | Relationship |
|---|---|
| **ROM Driver** | Provides fonts (`GetStandardFont`), sprite sheets, and audio assets for text and texture rendering. |
| **CPU Driver** | Provides `GetRuntime()` for time-based animations and `Delay()` for timed UI events. |
| **LCD Driver** | Simpler alternative for text-only output. Use the LCD for basic status and the Video Driver for rich graphics. |
| **Math3D** | Exposed as `video.Math3D`. Provides all 3D math functions (matrices, vectors, normals) used by the rendering pipeline. |
| **Audio Driver** | Often paired with the Video Driver for audiovisual presentations and UI feedback. |
| **Touch Signals** | Touch events are processed in `_update()`, which is called by `KRNL.Update()`. Tasks can react to touch via signals or poll `GetTouchState()` directly. |

---

## Limitations

* **Painter's algorithm** — Depth sorting is per-triangle and does not handle intersecting geometry correctly. Overlapping triangles at similar depths may exhibit z-fighting or incorrect ordering. There is no z-buffer.
* **No instancing** — Each draw call is processed individually. For large meshes, call `DrawMesh()` which loops internally, but there is no GPU instancing or batch optimization.
* **Single fragment shader** — Only one fragment shader can be active at a time. To mix shading styles in a single frame, you would need to flush the queue manually between shader changes (which requires extending the driver).
* **Fixed-function 2D** — 2D drawing methods are direct hardware wrappers with no shader support, no transform stack, and no sub-pixel rendering.
* **No anti-aliasing** — Neither 2D nor 3D rendering includes anti-aliasing. Edges may appear jagged.
* **Touch resolution** — Touch position precision depends on the hardware. No gesture recognition (pinch, swipe, rotate) is provided.
* **No off-screen textures** — Render buffers are blitted to screen at `FrameEnd()` but cannot be read back as textures for post-processing.
* **Winding order matters** — Back-face culling assumes a consistent vertex winding order. Mixed winding in a mesh will cause some faces to disappear.
