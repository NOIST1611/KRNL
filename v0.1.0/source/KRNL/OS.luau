local KRNL = {}

local Core   = require("/KRNL/kernel/Core")
local Kernel = Core.Boot()

export type KernelSingleton = Core.KernelSingleton
export type Driver = Core.Driver
export type CPUDriver = Core.CPUDriver
export type LCDDriver = Core.LCDDriver
export type Task = Core.Task
export type TaskConfig = Core.TaskConfig
export type Color = Core.Color
export type KeyboardDriver = Core.KeyboardDriver
export type VideoDriver = Core.VideoDriver
export type VideoTexture = Core.VideoTexture
export type RomDriver = Core.RomDriver
export type LedDriver = Core.LedDriver
export type LedButtonDriver = Core.LedButtonDriver
export type SwitchDriver = Core.SwitchDriver
export type SliderDriver = Core.SliderDriver
export type RealityDriver = Core.RealityDriver
export type FlashMemoryDriver = Core.FlashMemoryDriver
export type VFSInstance = Core.VFSInstance

function KRNL.CreateTask(config: TaskConfig): Task
    return Kernel:CreateTask(config)
end

function KRNL.LaunchTask(config: TaskConfig): Task
    local task = Kernel:CreateTask(config)
    task:SetState("running")
    return task
end

function KRNL.KillTask(pid: string): ()
    Kernel:KillTask(pid)
end

function KRNL.GetDriver(name: string): Driver?
    return Kernel:GetDriver(name)
end

function KRNL.GetUtility(name: string): any
		return Kernel:GetUtility(name)
end

function KRNL.GetVFS(name: string) : VFSInstance?
		return Kernel:GetVFS(name)
end

function KRNL.Update(): ()
    Core:_update()
end

return KRNL
