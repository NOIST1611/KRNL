export type DelayedCallback = {
    fn   : (...any) -> (),
    time : number,
    args : { [number]: any, n: number },
}

export type NodeType = "file" | "directory"
export type Node = {
    name: string,
    type: NodeType,
    content: string?,
    children: { [string]: Node }?,
    size: number,
    modified: number
}

export type BaseDriverData = {
    instance_name : string,
}

export type CPUDriverUserdata = {
    dt                : number,
    runtime           : number,
    delayed_callbacks : { DelayedCallback },
}

export type CPUDriverData = BaseDriverData & {
    userdata : CPUDriverUserdata,
}

export type Driver = {
    instance    : any,
    _driverData : BaseDriverData,
    _update     : (self: Driver) -> (),
}

export type HookableDriver = Driver & {
    GetEventFunction : (self: HookableDriver) -> (sender: any, data: any) -> (),
}

export type CPUDriver = Driver & {
    _driverData  : CPUDriverData,

    GetDeltaTime : (self: CPUDriver) -> number,
    GetRuntime   : (self: CPUDriver) -> number,
    GetTPS       : (self: CPUDriver) -> number,
    GetUsage     : (self: CPUDriver) -> number,
    Delay        : (self: CPUDriver, callback: (...any) -> (), time: number?, ...any) -> (),
}

export type LcdDriverUserdata = {
    bg_color   : any,
    text_color : any,
}

export type LcdDriverData = BaseDriverData & {
    userdata : LcdDriverUserdata,
}

export type LcdDriver = Driver & {
    _driverData : LcdDriverData,
		
    SetText   : (self: LcdDriver, text: string) -> (),
    GetText   : (self: LcdDriver) -> string,
    Clear     : (self: LcdDriver) -> (),
    PrintLine : (self: LcdDriver, line: number, text: string) -> (),
    CenterLine: (self: LcdDriver, line: number, text: string) -> (),
		
    SetTextColor       : (self: LcdDriver, color: any) -> (),
    SetBackgroundColor : (self: LcdDriver, color: any) -> (),
    GetTextColor       : (self: LcdDriver) -> any,
    GetBackgroundColor : (self: LcdDriver) -> any,
}

export type KeyboardDriverUserdata = {
    buffer         : string,
    held_keys      : { [string]: boolean },
    buffer_limit   : number,
    event_function : (sender: any, event: any) -> (),
}

export type KeyboardDriverData = BaseDriverData & {
    userdata : KeyboardDriverUserdata,
}

export type KeyboardDriver = Driver & {
    _driverData : KeyboardDriverData,
		
    InputBegan    : any,
    InputEnded    : any,
    BufferChanged : any,
    BufferSubmit  : any,
		
    GetBuffer      : (self: KeyboardDriver) -> string,
    Flush          : (self: KeyboardDriver) -> (),
    IsKeyHeld      : (self: KeyboardDriver, key: string) -> boolean,
    SetBufferLimit : (self: KeyboardDriver, limit: number) -> (),
    HookEventChannel : (self: KeyboardDriver) -> (sender: any, event: any) -> (),
}

export type TaskRegistry   = { [string]: Task }
export type DriverRegistry = { [string]: Driver }
export type VFSRegistry    = { [string]: VFSInstance }

export type VideoTexture = {
    sheet  : any,
    sx     : number?,
    sy     : number?,
    offset : any?,
    size   : any?,
    tint   : any?,
    bg     : any?,
}

export type VideoTriQueued = {
    sx1: number, sy1: number,
    sx2: number, sy2: number,
    sx3: number, sy3: number,
    sx4: number, sy4: number,
    nx: number, ny: number, nz: number,
    depth   : number,
    texture : VideoTexture?,
    is_quad : boolean,
}

export type VideoDriverUserdata = {
    target_buffer   : number,
    buffer_active   : boolean,
    width           : number,
    height          : number,
    camera          : any,
    proj_matrix     : any,
    view_matrix     : any,
    model_matrix    : any,
    mvp_matrix      : any,
    vertex_shader   : ((world_pos: any, uniforms: any) -> (number?, number?, number?))?,
    fragment_shader : ((tri: VideoTriQueued, uniforms: any) -> any)?,
    uniforms        : { [string]: any },
    tri_queue       : { VideoTriQueued },
}

export type VideoDriverData = BaseDriverData & {
    userdata : VideoDriverUserdata,
}

export type VideoDriver = Driver & {
    Math3D      : any,
    _driverData : VideoDriverData,

    GetSize            : (self: VideoDriver) -> (number, number),
    SetTargetBuffer    : (self: VideoDriver, index: number) -> (),
    SetBufferSize      : (self: VideoDriver, index: number, w: number, h: number) -> (),
    FrameStart         : (self: VideoDriver) -> (),
    FrameEnd           : (self: VideoDriver) -> (),

    SetVertexShader        : (self: VideoDriver, fn: any) -> (),
    SetFragmentShader      : (self: VideoDriver, fn: any) -> (),
    SetUniform             : (self: VideoDriver, key: string, value: any) -> (),
    GetUniform             : (self: VideoDriver, key: string) -> any,
    UseDefaultVertexShader : (self: VideoDriver) -> (),
    UseDefaultFragmentShader : (self: VideoDriver, flat_color: any?) -> (),
    UseLambertShader       : (self: VideoDriver, light_dir: any?, base_color: any?) -> (),

    SetCamera      : (self: VideoDriver, eye: any, center: any, up: any, fov: number?) -> (),
    SetClipPlanes  : (self: VideoDriver, near: number, far: number) -> (),
    SetTransform   : (self: VideoDriver, pos: any, rot: any, scale: any) -> (),
    SetModelMatrix : (self: VideoDriver, mat: any) -> (),

    DrawTri3D            : (self: VideoDriver, v1: any, v2: any, v3: any) -> (),
    DrawTri3DTextured    : (self: VideoDriver, v1: any, v2: any, v3: any, tex: VideoTexture) -> (),
    DrawQuad3D           : (self: VideoDriver, v1: any, v2: any, v3: any, v4: any) -> (),
    DrawQuad3DTextured   : (self: VideoDriver, v1: any, v2: any, v3: any, v4: any, tex: VideoTexture) -> (),
    DrawMesh             : (self: VideoDriver, mesh: any) -> (),
    DrawMeshTextured     : (self: VideoDriver, mesh: any, default_tex: VideoTexture?) -> (),

    Clear          : (self: VideoDriver, col: any) -> (),
    SetPixel       : (self: VideoDriver, x: number, y: number, col: any) -> (),
    DrawLine       : (self: VideoDriver, x1: number, y1: number, x2: number, y2: number, col: any) -> (),
    DrawRect       : (self: VideoDriver, x1: number, y1: number, x2: number, y2: number, col: any) -> (),
    FillRect       : (self: VideoDriver, x1: number, y1: number, x2: number, y2: number, col: any) -> (),
    DrawCircle     : (self: VideoDriver, x: number, y: number, r: number, col: any) -> (),
    FillCircle     : (self: VideoDriver, x: number, y: number, r: number, col: any) -> (),
    DrawTriangle   : (self: VideoDriver, x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, col: any) -> (),
    FillTriangle   : (self: VideoDriver, x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, col: any) -> (),
    DrawText       : (self: VideoDriver, x: number, y: number, font: any, text: string, tc: any, bc: any) -> (),
    DrawSprite     : (self: VideoDriver, x: number, y: number, sheet: any, sx: number, sy: number, tint: any, bg: any) -> (),
    DrawPointGrid  : (self: VideoDriver, ox: number, oy: number, dist: number, col: any) -> (),

    GetTouchState    : (self: VideoDriver) -> boolean,
    IsTouchDown      : (self: VideoDriver) -> boolean,
    IsTouchUp        : (self: VideoDriver) -> boolean,
    GetTouchPosition : (self: VideoDriver) -> (number, number),
}

export type RomDriverData = BaseDriverData & {
    userdata : {},
}

export type RomDriver = Driver & {
    _driverData : RomDriverData,
		
    GetSprite       : (self: RomDriver, name: string) -> any,
    GetSystemSprite : (self: RomDriver, name: string) -> any,
    GetStandardFont : (self: RomDriver) -> any,
		
    GetAudio        : (self: RomDriver, name: string) -> any,
    GetSystemAudio  : (self: RomDriver, name: string) -> any,
		
    GetCode         : (self: RomDriver, name: string) -> any,
		
    GetAsset        : (self: RomDriver, name: string) -> any,
    ListAssets      : (self: RomDriver) -> { string },
    ListSprites     : (self: RomDriver) -> { string },
    ListAudio       : (self: RomDriver) -> { string },
}

export type LedDriverUserdata = {
    led_color : any,
    state     : boolean,
}

export type LedDriverData = BaseDriverData & {
    userdata : LedDriverUserdata,
}

export type LedDriver = Driver & {
    _driverData : LedDriverData,

    SetColor : (self: LedDriver, clr: any) -> (),
    GetColor : (self: LedDriver) -> any,
    SetState : (self: LedDriver, state: boolean) -> (),
    GetState : (self: LedDriver) -> boolean,
}

export type LedButtonDriverUserdata = {
    led_color      : any,
    led_state      : boolean,
    event_function : (sender: any, event: any) -> (),
}

export type LedButtonDriverData = BaseDriverData & {
    userdata : LedButtonDriverUserdata,
}

export type LedButtonDriver = Driver & {
    _driverData : LedButtonDriverData,

    OnPressed  : any,
    OnReleased : any,

    SetColor       : (self: LedButtonDriver, clr: any) -> (),
    GetColor       : (self: LedButtonDriver) -> any,
    SetLedState    : (self: LedButtonDriver, state: boolean) -> (),
    GetLedState    : (self: LedButtonDriver) -> boolean,
    IsPressed      : (self: LedButtonDriver) -> boolean,
}

export type SwitchDriverUserdata = {
    state : boolean,
}

export type SwitchDriverData = BaseDriverData & {
    userdata : SwitchDriverUserdata,
}

export type SwitchDriver = Driver & {
    _driverData  : SwitchDriverData,
    StateChanged : any,

    SetState : (self: SwitchDriver, state: boolean) -> (),
    GetState : (self: SwitchDriver) -> boolean,
}

export type SliderDriverUserdata = {
    value : number,
}

export type SliderDriverData = BaseDriverData & {
    userdata : SliderDriverUserdata,
}

export type SliderDriver = Driver & {
    _driverData  : SliderDriverData,
    ValueChanged : any,

    SetValue  : (self: SliderDriver, value: number) -> (),
    GetValue  : (self: SliderDriver) -> number,
    IsMoving  : (self: SliderDriver) -> boolean,
}

export type RealityDateTime = {
    year  : number,
    month : number,
    day   : number,
    yday  : number,
    wday  : number,
    hour  : number,
    min   : number,
    sec   : number,
    isdst : boolean,
}

export type RealityDriverUserdata = {}

export type RealityDriverData = BaseDriverData & {
    userdata : RealityDriverUserdata,
}

export type RealityDriver = Driver & {
    _driverData : RealityDriverData,
		
    GetCPUUsage      : (self: RealityDriver) -> number,
    GetCPUCoresUsage : (self: RealityDriver) -> { number },
		
    GetRAMAvailable : (self: RealityDriver) -> number,
    GetRAMUsed      : (self: RealityDriver) -> number,
    GetRAMTotal     : (self: RealityDriver) -> number,
		
    GetNetworkSent     : (self: RealityDriver) -> number,
    GetNetworkReceived : (self: RealityDriver) -> number,
		
    GetDateTime    : (self: RealityDriver) -> RealityDateTime,
    GetDateTimeUTC : (self: RealityDriver) -> RealityDateTime,
    GetTimeString  : (self: RealityDriver) -> string,
    GetDateString  : (self: RealityDriver) -> string,
		
    LoadSprite   : (self: RealityDriver, filename: string, sw: number, sh: number) -> any,
    LoadAudio    : (self: RealityDriver, filename: string) -> any,
    UnloadAsset  : (self: RealityDriver, filename: string) -> (),
    ListDir      : (self: RealityDriver, directory: string) -> { string },
    GetFileMeta  : (self: RealityDriver, filename: string) -> any,
}

export type FlashMemoryDriverData = BaseDriverData

export type FlashMemoryDriver = Driver & {
    _driverData : FlashMemoryDriverData,

    GetUsage : (self: FlashMemoryDriver) -> (number, string, number),
    GetSize  : (self: FlashMemoryDriver) -> (number, string),
    Save     : (self: FlashMemoryDriver, data: {any}) -> boolean,
    Load     : (self: FlashMemoryDriver) -> {any},
}

export type KernelFlags = {
    _driversLoaded : boolean,
}

export type VFSInstance = {
    driver: any,
    mounted: boolean,
    root: Node,
		
    Mount: (self: VFSInstance) -> boolean,
    Commit: (self: VFSInstance) -> boolean,
		
    Write: (self: VFSInstance, path: string, content: string) -> boolean,
    Read: (self: VFSInstance, path: string) -> string?,
    WriteTable: (self: VFSInstance, path: string, data: {any}) -> boolean,
    ReadTable: (self: VFSInstance, path: string) -> {any}?,
		
    MakeDir: (self: VFSInstance, path: string) -> boolean,
    List: (self: VFSInstance, path: string) -> {string}?,
		
    Remove: (self: VFSInstance, path: string) -> boolean,
    RemoveAll: (self: VFSInstance, path: string) -> boolean,
    Exists: (self: VFSInstance, path: string) -> boolean,
    IsFile: (self: VFSInstance, path: string) -> boolean,
    IsDir: (self: VFSInstance, path: string) -> boolean,
    Stat: (self: VFSInstance, path: string) -> Node?,
    Copy: (self: VFSInstance, src: string, dst: string) -> boolean,
    Move: (self: VFSInstance, src: string, dst: string) -> boolean,
		
    _traverse: (self: VFSInstance, path: string) -> (Node?, Node?, string?),
    _createDefaultStructure: (self: VFSInstance) -> (),
}

export type KernelSingleton = {
    tasks   : TaskRegistry,
    drivers : DriverRegistry,
    _flags  : KernelFlags,
		vfs     : VFSRegistry,
		
    CreateTask : (self: KernelSingleton, task_config: TaskConfig) -> Task,
    KillTask   : (self: KernelSingleton, pid: string) -> (),
    GetDriver  : (self: KernelSingleton, name: string) -> Driver?,
		GetUtility : (self: KernelSingleton, name: string) -> any,
		GetVFS     : (self: KernelSingleton,name: string) -> any,
}

export type Task = {
    pid    : string,
    name   : string,
    data   : { [any]: any },
    state  : "running" | "idle",
    Update : ((self: Task) -> ())?,

    SetState : (self: Task, state: "running" | "idle") -> (),
    Kill     : (self: Task, registry: TaskRegistry) -> (),
}

export type TaskConfig = {
    name           : string?,
    Data           : { [any]: any }?,
    UpdateFunction : ((self: Task) -> ())?,
}

return {}
