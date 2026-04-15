local switch = {}
switch.__index = switch

local KernelConfig = require("/KRNL/kernel/Config")
local Types = require("/KRNL/kernel/Utils/Types")
local BetterEvents = require("/KRNL/kernel/Utils/BetterEvents")
local Color4 = require("/KRNL/kernel/Utils/Color4")

type DriverRegistry = Types.DriverRegistry
type Color4 = Color4.Color4
type SwitchDriver = Types.SwitchDriver

local Prefix = "[SWITCH DRIVER]:"

function switch.AddDriver(instance: Switch, name: string, registry: DriverRegistry): SwitchDriver?
    if instance.Type ~= "Switch" then
        logWarning(string.format("%s Error while trying to load Driver: Invalid component", Prefix))
        return nil
    end
		
    local Driver = setmetatable({}, switch) :: any
    Driver.instance = instance
    Driver._driverData = {
        instance_name = name,
        userdata = {
           state = false,
        },
    }
		
    Driver.StateChanged = BetterEvents.new(name .. "_statechanged")

    registry[name] = Driver
    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function switch.GetDriver(name: string, registry: DriverRegistry): SwitchDriver?
    local driver = registry[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function switch:SetState(state: boolean): ()
		local instance = self.instance :: Switch
		
		instance.State = state
end

function switch:GetState(): boolean
		local data = self._driverData.userdata
		
		return data.state
end

function switch:_update(): ()
		local data = self._driverData.userdata
		local instance = self.instance :: Switch
		
		if instance.State ~= data.state then
				self.StateChanged:Fire()
		end
		
		data.state = instance.State
end

return switch
