local Video = {}
Video.__index = Video

local Types  = require("/KRNL/kernel/Utils/Types")
local Math3D = require("/KRNL/kernel/Utils/3DMath")
local Prefix = "[VIDEOCHIP DRIVER]:"

type DriverRegistry = Types.DriverRegistry
type VideoDriver = Types.VideoDriver

local function _rebuildMVP(data)
    data.mvp_matrix = Math3D:mat4_mult_mat4(
        data.proj_matrix,
        Math3D:mat4_mult_mat4(data.view_matrix, data.model_matrix)
    )
end

function Video.AddDriver(instance: VideoChip, name: string, registry: DriverRegistry) : VideoDriver?
    if instance.Type ~= "VideoChip" then
        logWarning(string.format("%s Invalid component: %s", Prefix, name))
        return nil
    end

    local Driver = setmetatable({}, Video) :: any
    Driver.instance = instance
    Driver.Math3D = Math3D

    Driver._driverData = {
        instance_name = name,
        userdata = {
            target_buffer = 1,
            buffer_active = false,
            width = instance.Width,
            height = instance.Height,
            camera = {
                eye = vec3(0, 0, -5),
                center = vec3(0, 0,  0),
                up = vec3(0, 1,  0),
                fov = Math3D:radians(60),
                near = 0.1,
                far = 1000,
            },
            proj_matrix = Math3D:mat4_perspective(instance.Width / instance.Height, Math3D:radians(60), 0.1, 1000),
            view_matrix = Math3D:mat4(),
            model_matrix = Math3D:mat4(),
            mvp_matrix = Math3D:mat4(),
            vertex_shader = nil,
            fragment_shader = nil,
            uniforms = {},
            tri_queue = {},
        },
    }

    registry[name] = Driver
    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function Video.GetDriver(name: string, registry: DriverRegistry) : VideoDriver?
    local driver = registry[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function Video:SetTargetBuffer(index: number) : ()
    local chip = self.instance
    local data = self._driverData.userdata
    local count = #chip.RenderBuffers

    if index > count then
        logWarning(string.format("%s Buffer index %d out of range (max %d)", Prefix, index, count))
        index = count
    end

    data.target_buffer = index
    if data.buffer_active then
        chip:RenderOnBuffer(index)
    end
end

function Video:SetBufferSize(index: number, w: number, h: number) : ()
    local data = self._driverData.userdata
    data.width = w
    data.height = h

    self.instance:SetRenderBufferSize(index, w, h)

    local cam = data.camera
    data.proj_matrix = Math3D:mat4_perspective(w / h, cam.fov, cam.near, cam.far)
    _rebuildMVP(data)
end

function Video:GetSize(): (number, number)
    local d = self._driverData.userdata
    return d.width, d.height
end

function Video:FrameStart() : ()
    local chip = self.instance
    local data = self._driverData.userdata

    if data.buffer_active then return end
    data.buffer_active = true
    data.tri_queue     = {}

    chip:RenderOnBuffer(data.target_buffer)
    chip:Clear(color.black)
end

function Video:FrameEnd() : ()
    local chip = self.instance
    local data = self._driverData.userdata

    if not data.buffer_active then return end

    self:_flushTriQueue()

    data.buffer_active = false

    local buf = chip.RenderBuffers[data.target_buffer]
    if buf then
        chip:RenderOnScreen()
        chip:Clear(color.black)
        chip:DrawRenderBuffer(vec2(0, 0), buf, data.width, data.height)
    else
        chip:RenderOnScreen()
    end
end

function Video:SetVertexShader(fn): ()
    self._driverData.userdata.vertex_shader = fn
end

function Video:SetFragmentShader(fn): ()
    self._driverData.userdata.fragment_shader = fn
end

function Video:SetUniform(key: string, value: any): ()
    self._driverData.userdata.uniforms[key] = value
end

function Video:GetUniform(key: string): any
    return self._driverData.userdata.uniforms[key]
end

function Video:UseDefaultVertexShader() : ()
    local data = self._driverData.userdata
    self._driverData.userdata.vertex_shader = function(world_pos, uniforms)
        local clip = Math3D:mat4_transform(data.mvp_matrix, world_pos)
        if clip.W == 0 or clip.W < 0 then return nil end
        local screen = Math3D:vec4_to_screen(clip, data.width, data.height)
        return screen.X, screen.Y, clip.Z / clip.W
    end
end

function Video:UseDefaultFragmentShader(flat_color) : ()
    flat_color = flat_color or color.white
    self._driverData.userdata.fragment_shader = function(tri, uniforms)
        return flat_color
    end
end

function Video:UseLambertShader(light_dir, base_color) : ()
    light_dir = light_dir  or vec3(0.5, 1, 0.5)
    base_color = base_color or color.white
    local ld = Math3D:vec3_normalize(light_dir)

    self._driverData.userdata.fragment_shader = function(tri, uniforms)
        local n   = Math3D:vec3_normalize(vec3(tri.nx, tri.ny, tri.nz))
        local dot = math.max(0, Math3D:vec3_dot(n, ld))
        local intensity = math.min(1, 0.15 + dot)
        return ColorRGBA(
            math.floor(base_color.r * intensity),
            math.floor(base_color.g * intensity),
            math.floor(base_color.b * intensity),
            255
        )
    end
end

function Video:SetCamera(eye: vec3, center: vec3, up: vec3, fov: number?): ()
    local data = self._driverData.userdata
    local cam = data.camera

    cam.eye = eye
    cam.center = center
    cam.up = up
    cam.fov = fov and Math3D:radians(fov) or cam.fov

    data.view_matrix = Math3D:mat4_look_at(eye, center, up)
    data.proj_matrix = Math3D:mat4_perspective(data.width / data.height, cam.fov, cam.near, cam.far)
    _rebuildMVP(data)
end

function Video:SetClipPlanes(near: number, far: number): ()
    local data = self._driverData.userdata
    local cam = data.camera
    cam.near = near
    cam.far = far
    data.proj_matrix = Math3D:mat4_perspective(data.width / data.height, cam.fov, near, far)
    _rebuildMVP(data)
end

function Video:SetTransform(pos: vec3, rot: vec3, scale: vec3): ()
    local data = self._driverData.userdata
    data.model_matrix = Math3D:mat4_model_matrix(pos, rot, scale or vec3(1, 1, 1))
    _rebuildMVP(data)
end

function Video:SetModelMatrix(mat) : ()
    local data = self._driverData.userdata
    data.model_matrix = mat
    _rebuildMVP(data)
end

function Video:DrawTri3D(v1: vec3, v2: vec3, v3: vec3): ()
    local data = self._driverData.userdata
    local vs = data.vertex_shader
    if not vs then logWarning(Prefix .. " No vertex shader set") return end

    local sx1,sy1,sd1 = vs(v1, data.uniforms)
    local sx2,sy2,sd2 = vs(v2, data.uniforms)
    local sx3,sy3,sd3 = vs(v3, data.uniforms)
    if not sx1 or not sx2 or not sx3 then return end

    if (sx2-sx1)*(sy3-sy1) - (sy2-sy1)*(sx3-sx1) <= 0 then return end

    local normal = Math3D:get_triangle_normal({v1, v2, v3})
    table.insert(data.tri_queue, {
        sx1=sx1, sy1=sy1, sx2=sx2, sy2=sy2, sx3=sx3, sy3=sy3,
        sx4=sx3, sy4=sy3,
        nx=normal.X, ny=normal.Y, nz=normal.Z,
        depth=(sd1+sd2+sd3)/3,
        texture=nil, is_quad=false,
    })
end

function Video:DrawTri3DTextured(v1: vec3, v2: vec3, v3: vec3, texture): ()
    local data = self._driverData.userdata
    local vs = data.vertex_shader
    if not vs then logWarning(Prefix .. " No vertex shader set") return end

    local sx1,sy1,sd1 = vs(v1, data.uniforms)
    local sx2,sy2,sd2 = vs(v2, data.uniforms)
    local sx3,sy3,sd3 = vs(v3, data.uniforms)
    if not sx1 or not sx2 or not sx3 then return end

    if (sx2-sx1)*(sy3-sy1) - (sy2-sy1)*(sx3-sx1) <= 0 then return end

    local normal = Math3D:get_triangle_normal({v1, v2, v3})
    table.insert(data.tri_queue, {
        sx1=sx1, sy1=sy1, sx2=sx2, sy2=sy2, sx3=sx3, sy3=sy3,
        sx4=sx3, sy4=sy3,
        nx=normal.X, ny=normal.Y, nz=normal.Z,
        depth=(sd1+sd2+sd3)/3,
        texture=texture, is_quad=false,
    })
end

function Video:DrawQuad3D(v1: vec3, v2: vec3, v3: vec3, v4: vec3): ()
    self:DrawQuad3DTextured(v1, v2, v3, v4, nil)
end

function Video:DrawQuad3DTextured(v1: vec3, v2: vec3, v3: vec3, v4: vec3, texture): ()
    local data = self._driverData.userdata
    local vs = data.vertex_shader
    if not vs then logWarning(Prefix .. " No vertex shader set") return end

    local sx1,sy1,sd1 = vs(v1, data.uniforms)
    local sx2,sy2,sd2 = vs(v2, data.uniforms)
    local sx3,sy3,sd3 = vs(v3, data.uniforms)
    local sx4,sy4,sd4 = vs(v4, data.uniforms)
    if not sx1 or not sx2 or not sx3 or not sx4 then return end

    if (sx2-sx1)*(sy3-sy1) - (sy2-sy1)*(sx3-sx1) <= 0 then return end

    local normal = Math3D:get_triangle_normal({v1, v2, v3})
    table.insert(data.tri_queue, {
        sx1=sx1, sy1=sy1, sx2=sx2, sy2=sy2, sx3=sx3, sy3=sy3,
        sx4=sx4, sy4=sy4,
        nx=normal.X, ny=normal.Y, nz=normal.Z,
        depth=(sd1+sd2+sd3+sd4)/4,
        texture=texture, is_quad=true,
    })
end

function Video:DrawMesh(mesh) : ()
    for _, tri in ipairs(mesh) do
        self:DrawTri3D(tri[1], tri[2], tri[3])
    end
end

function Video:DrawMeshTextured(mesh, default_texture): ()
    for _, tri in ipairs(mesh) do
        local tex = tri[4] or default_texture
        if tex then
            self:DrawTri3DTextured(tri[1], tri[2], tri[3], tex)
        else
            self:DrawTri3D(tri[1], tri[2], tri[3])
        end
    end
end

function Video:_flushTriQueue() : ()
    local data = self._driverData.userdata
    local chip = self.instance
    local fs = data.fragment_shader
    local queue = data.tri_queue

    if #queue == 0 then return end

    table.sort(queue, function(a, b) return a.depth > b.depth end)

    for _, tri in ipairs(queue) do
        local tex = tri.texture

        if tex then
            local tint = tex.tint or color.white
            local bg   = tex.bg   or color.clear
            local p1   = vec2(tri.sx1, tri.sy1)
            local p2   = vec2(tri.sx2, tri.sy2)
            local p3   = vec2(tri.sx3, tri.sy3)
            local p4   = tri.is_quad and vec2(tri.sx4, tri.sy4) or p3

            if tex.offset and tex.size then
                chip:RasterCustomSprite(p1, p2, p3, p4, tex.sheet, tex.offset, tex.size, tint, bg)
            else
                chip:RasterSprite(p1, p2, p3, p4, tex.sheet, tex.sx or 0, tex.sy or 0, tint, bg)
            end
        else
            local col = color.white
            if fs then col = fs(tri, data.uniforms) end

            if tri.is_quad then
                chip:FillTriangle(vec2(tri.sx1,tri.sy1), vec2(tri.sx2,tri.sy2), vec2(tri.sx3,tri.sy3), col)
                chip:FillTriangle(vec2(tri.sx1,tri.sy1), vec2(tri.sx3,tri.sy3), vec2(tri.sx4,tri.sy4), col)
            else
                chip:FillTriangle(vec2(tri.sx1,tri.sy1), vec2(tri.sx2,tri.sy2), vec2(tri.sx3,tri.sy3), col)
            end
        end
    end
end

function Video:Clear(col: color) : ()                    self.instance:Clear(col) end
function Video:SetPixel(x,y,col) : ()                  self.instance:SetPixel(vec2(x,y), col) end
function Video:DrawLine(x1,y1,x2,y2,col) : ()            self.instance:DrawLine(vec2(x1,y1), vec2(x2,y2), col) end
function Video:DrawRect(x1,y1,x2,y2,col) : ()           self.instance:DrawRect(vec2(x1,y1), vec2(x2,y2), col) end
function Video:FillRect(x1,y1,x2,y2,col) : ()           self.instance:FillRect(vec2(x1,y1), vec2(x2,y2), col) end
function Video:DrawCircle(x,y,r,col) : ()              self.instance:DrawCircle(vec2(x,y), r, col) end
function Video:FillCircle(x,y,r,col) : ()                self.instance:FillCircle(vec2(x,y), r, col) end
function Video:DrawTriangle(x1,y1,x2,y2,x3,y3,col) : () self.instance:DrawTriangle(vec2(x1,y1), vec2(x2,y2), vec2(x3,y3), col) end
function Video:FillTriangle(x1,y1,x2,y2,x3,y3,col) : () self.instance:FillTriangle(vec2(x1,y1), vec2(x2,y2), vec2(x3,y3), col) end
function Video:DrawText(x,y,font,text,tc,bc) : ()        self.instance:DrawText(vec2(x,y), font, text, tc, bc) end
function Video:DrawSprite(x,y,sheet,sx,sy,tint,bg) : ()  self.instance:DrawSprite(vec2(x,y), sheet, sx, sy, tint, bg) end
function Video:DrawPointGrid(ox,oy,dist,col): ()        self.instance:DrawPointGrid(vec2(ox,oy), dist, col) end

function Video:GetTouchState(): boolean             return self.instance.TouchState end
function Video:IsTouchDown(): boolean               return self.instance.TouchDown end
function Video:IsTouchUp(): boolean                 return self.instance.TouchUp end
function Video:GetTouchPosition(): (number, number)
    local p = self.instance.TouchPosition
    return p.x, p.y
end

function Video:_update() : ()
		
end

return Video
