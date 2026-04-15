local cpu = {}
cpu.__index = cpu

local KernelConfig = require("/KRNL/kernel/Config")
local Types = require("/KRNL/kernel/Utils/Types")

type CPUDriver = Types.CPUDriver
type CPUDriverData = Types.CPUDriverData
type CPUDriverUserdata = Types.CPUDriverUserdata
type DriverRegistry = Types.DriverRegistry
type DelayedCallback = Types.DelayedCallback

local Prefix = "[CPU DRIVER]:"
local TARGET_TPS = 60
local TARGET_DT = 1 / TARGET_TPS

function cpu.AddDriver(instance: CPU, name: string, registry: DriverRegistry): CPUDriver?
    if instance.Type ~= "CPU" then
        logWarning(string.format("%s Error while trying to load Driver: Invalid component", Prefix))
        return nil
    end

    local Driver = setmetatable({}, cpu) :: any
    Driver.instance = instance
    Driver._driverData = {
        instance_name = name,
        userdata = {
            dt = 0,
            runtime = 0,
            delayed_callbacks = {},
        },
    } :: CPUDriverData

    registry[name] = Driver

    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function cpu.GetDriver(name: string, registry: DriverRegistry): CPUDriver?
    local driver = registry[name] :: CPUDriver
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function cpu:GetDeltaTime(): number
    return (self :: CPUDriver)._driverData.userdata.dt
end

function cpu:GetRuntime(): number
    return (self :: CPUDriver)._driverData.userdata.runtime
end

function cpu:GetTPS(): number
    local dt = (self :: CPUDriver)._driverData.userdata.dt
    if dt <= 0 then return TARGET_TPS end
    return 1 / dt
end

function cpu:GetUsage(): number
		local dt = (self :: CPUDriver)._driverData.userdata.dt
		if dt <= 0 then return 0 end
		
		local tps = 1 / dt
		local load = (TARGET_TPS / tps) * 100
		return math.clamp(load, 0, 100)
end

function cpu:Delay(callback: (...any) -> (), time: number?, ...: any): ()
    local data = (self :: CPUDriver)._driverData.userdata
    local args = table.pack(...)
    local entry : DelayedCallback = {
        fn   = callback,
        time = data.runtime + (time or 0),
        args = args,
    }
    table.insert(data.delayed_callbacks, entry)
end

function cpu:_update(): ()
    local data = (self :: CPUDriver)._driverData.userdata
    local callbacks = data.delayed_callbacks

    data.dt = self.instance.DeltaTime
    data.runtime += data.dt

    local runtime = data.runtime

    for i = #callbacks, 1, -1 do
        local cb = callbacks[i]
        if runtime >= cb.time then
            cb.fn(table.unpack(cb.args, 1, cb.args.n))
            table.remove(callbacks, i)
        end
    end
end

return cpu
