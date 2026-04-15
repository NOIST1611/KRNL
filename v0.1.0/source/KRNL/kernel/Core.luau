local Core   = {}
local System = {}
System.__index = System

local KernelConfig = require("Config")
local BetterEvents = require("Utils/BetterEvents")
local Color4       = require("Utils/Color4")
local Types        = require("Utils/Types")
local Scheduler    = require("Scheduler")
local VFS          = require("VFS")

local Drivers = {
    ["CPU"] = require("Drivers/CPU"),
		["Lcd"] = require("Drivers/LcdDisplay"),
		["KeyboardChip"] = require("Drivers/KeyboardChip"),
		["VideoChip"] = require("Drivers/VideoChip"),
		["ROM"] = require("Drivers/ROM"),
		["Led"] = require("Drivers/Led"),
		["LedButton"] = require("Drivers/LedButton"),
		["Switch"] = require("Drivers/Switch"),
		["Slider"] = require("Drivers/Slider"),
		["RealityChip"] = require("Drivers/RealityChip"),
		["FlashMemory"] = require("Drivers/FlashMemory"),
}

local Utils = {
	["Color4"] = Color4,
	["BetterEvents"] = BetterEvents,
}

type TaskRegistry = Types.TaskRegistry
type DriverRegistry = Types.DriverRegistry
type KernelFlags = Types.KernelFlags

export type TaskConfig = Types.TaskConfig
export type Task = Types.Task
export type Driver = Types.Driver
export type CPUDriver = Types.CPUDriver
export type LCDDriver = Types.LcdDriver
export type KeyboardDriver = Types.KeyboardDriver
export type KernelSingleton = Types.KernelSingleton
export type Color = Color4.Color4
export type VideoDriver = Types.VideoDriver
export type VideoTexture = Types.VideoTexture
export type RomDriver = Types.RomDriver
export type LedDriver = Types.LedDriver
export type LedButtonDriver = Types.LedButtonDriver
export type SwitchDriver = Types.SwitchDriver
export type SliderDriver = Types.SliderDriver
export type RealityDriver = Types.RealityDriver
export type FlashMemoryDriver = Types.FlashMemoryDriver
export type VFSInstance = Types.VFSInstance

local Singleton = {} :: KernelSingleton
local Prefix    = KernelConfig.KernelPrefix

local function GetComponentByName(name: string, component_list: { [string]: any }): { [string]: any }
    local components: { [string]: any } = {}
		
		local component = component_list[name]
		if component then components[name] = component end
		
    for i = 0, 100 do
        local component_name = name .. i
        local component      = component_list[component_name]
        if component then
            components[component_name] = component
        else
            break
        end
    end
    return components
end

function System:CreateTask(task_config: TaskConfig): Task
    return Scheduler.CreateTask(task_config, Singleton.tasks)
end

function System:KillTask(pid: string): ()
    local task = Scheduler.GetTask(pid, Singleton.tasks)
    task:Kill(Singleton.tasks)
end

function System:GetDriver(name: string): Driver?
		local driver = Singleton.drivers[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
        return nil
    end
    if not driver.instance then
        logWarning(string.format("%s Driver %s has no instance", Prefix, name))
        return nil
    end
    return driver
end

function System:GetUtility(name: string) : any
		local util = Utils[name]
		
		if not util then
				logWarning(string.format("%s Can't find utility with name %s", Prefix, name))
		end
		
		return util
end

function System:GetVFS(name: string) : VFSInstance?
		local fs = Singleton.vfs[name]
		
		if not fs then
				logWarning(string.format("%s Can't find VFS with name %s", Prefix, name))
		end
		
		return fs
end

function Core.Boot(): KernelSingleton
    if Singleton._flags then
        logWarning(string.format("%s Already booted", Prefix))
        return Singleton
    end

    Singleton = setmetatable({}, System)
    Singleton.tasks = {}
    Singleton.drivers = {}
		Singleton.vfs = {}
    Singleton._flags = {
        _driversLoaded = false,
    }

    if KernelConfig.AutoDriverLoad then
        Core:_loadDrivers(gdt.Motherboards[1])
    end
		
		Core:_loadVFS()

    log(string.format("%s Booted KRNL", Prefix))
    return Singleton
end

function Core:_loadVFS() : ()
		for _,vfs in Singleton.vfs do
				vfs:Mount()
		end
end

function Core:_loadDrivers(components: { [string]: any }): ()
    if not Singleton._flags then return end
    if Singleton._flags._driversLoaded then return end
    Singleton._flags._driversLoaded = true

    for name, driver_module in Drivers do
        local driver_instances = GetComponentByName(name, components)
        for instance_name, instance in driver_instances do
            local driver = driver_module.AddDriver(instance, instance_name, Singleton.drivers)
						if string.find(instance_name,"FlashMemory") then
								VFS.new(driver,instance_name,Singleton.vfs)
						end
        end
    end
end

function Core:_update(): ()
    local crashed = {}
		
    for _, task: Task in Singleton.tasks do
        if task.state ~= "idle" then
            if task.Update then
                local ok, err = pcall(task.Update, task)
                if not ok then
                    logWarning(string.format("%s Task %s crashed: %s", Prefix, task.pid, err))
                    table.insert(crashed, task)
                end
            end
        end
    end
		
    for _, task in crashed do
        task:Kill(Singleton.tasks)
    end
		
    for _, driver: Driver in Singleton.drivers do
        if driver._update then
						local ok,err = pcall(driver._update,driver)
            if not ok then logWarning(string.format("%s Driver: %s update error: %s", Prefix,driver._driverData.instance_name, err)) end
        end
    end
end

return Core
