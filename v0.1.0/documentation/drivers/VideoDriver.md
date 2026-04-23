
# VideoDriver Reference

The **VideoDriver** is a graphics abstraction for the `VideoChip`.
---

## The Rendering Lifecycle

KRNL uses a frame-buffer approach to render everything.

```lua
local video = KRNL.GetDriver("VideoChip0")

function update()
    video:FrameStart() -- Starts rendering

    -- 
    
    video:FrameEnd() -- Renders everything on screen
end
```

---

## Camera & Transformation (3D)

KRNL uses a standard **MVP (Model-View-Projection)** matrix system.

### `video:SetCamera(eye, center, up, fov?)`
Defines the viewer's position and perspective.
* `eye`: `vec3` (Camera position).
* `center`: `vec3` (Where the camera is looking).
* `up`: `vec3` (Upward vector, usually `vec3(0, 1, 0)`).
* `fov`: `number?` (Field of view in degrees, default 60).

### `video:SetTransform(pos, rot, scale)`
Defines the position, rotation, and scale of the next objects to be drawn.
* **Note:** Calling this automatically rebuilds the Model matrix and updates the MVP.

### `video:SetClipPlanes(near, far)`
Defines the rendering boundaries. Objects closer than `near` or further than `far` will be clipped.

---

## Shader System

KRNL allows you to inject custom logic into the rendering pipeline via **Vertex** and **Fragment** shaders.

### `video:SetVertexShader(fn)`
Processes 3D vertices into screen coordinates.
* **Input:** `(world_pos: vec3, uniforms: table)`
* **Output:** `(screen_x, screen_y, depth)` or `nil` to discard.

### `video:SetFragmentShader(fn)`
Determines the color of a triangle.
* **Input:** `(tri: VideoTriQueued, uniforms: table)`
* **Output:** `ColorRGBA`

### Built-in Shaders:
* `video:UseDefaultVertexShader()`: Standard perspective projection.
* `video:UseDefaultFragmentShader(color?)`: Renders everything in a solid flat color.
* `video:UseLambertShader(light_dir?, base_color?)`: Simple diffuse lighting based on triangle normals.

---

## Drawing Primitives

### 3D Drawing
* `video:DrawTri3D(v1, v2, v3)`: Draws a raw 3D triangle.
* `video:DrawQuad3D(v1, v2, v3, v4)`: Draws a 3D quad (split into two triangles internally).
* `video:DrawMesh(mesh)`: Draws a table of triangles.

### Textured Drawing
Requires a `VideoTexture` object: `{ sheet, sx, sy, tint, bg }`.
* `video:DrawTri3DTextured(v1, v2, v3, texture)`
* `video:DrawMeshTextured(mesh, default_texture)`

### 2D
These methods wrap the standard `VideoChip` API.
* `video:Clear(col)`, `video:SetPixel(x, y, col)`, `video:DrawLine(...)`.
* `video:FillRect(x1, y1, x2, y2, col)`.
* `video:DrawText(x, y, font, text, tc, bc)`.
* `video:DrawSprite(x, y, sheet, sx, sy, tint, bg)`.

---

## Interaction (Touch)

Provides easy access to the screen's touch/mouse interface.
* `video:GetTouchState()`: `boolean` (Is currently touching).
* `video:IsTouchDown()`: `boolean` (Triggered on the exact frame touch started).
* `video:GetTouchPosition()`: Returns `(x, y)`.

---

## Advanced: Uniforms & Buffers

### `video:SetUniform(key, value)`
Passes custom data (like time, light positions, or effects) into your shaders.
```lua
video:SetUniform("u_time", cpu:GetRuntime())
```

### `video:SetTargetBuffer(index)`
Sets which hardware render buffer to use.

---

## Example: Rendering a Rotating Cube
```lua
local video = KRNL.GetDriver("VideoChip0")
video:UseDefaultVertexShader()
video:UseLambertShader(vec3(1, 1, 1), color.orange)

KRNL.CreateTask({
    name = "Renderer",
    UpdateFunction = function()
        video:FrameStart()
        
        local t = cpu:GetRuntime()
        video:SetCamera(vec3(math.sin(t)*5, 2, math.cos(t)*5), vec3(0,0,0), vec3(0,1,0))
        
        -- Draw your mesh here
        video:DrawMesh(CUBE_MESH)
        
        video:FrameEnd()
    end
})

---
