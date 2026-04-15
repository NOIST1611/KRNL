local led = {}
led.__index = led

local KernelConfig = require("/KRNL/kernel/Config")
local Types        = require("/KRNL/kernel/Utils/Types")
local Color4 = require("/KRNL/kernel/Utils/Color4")

type DriverRegistry = Types.DriverRegistry
type Color4 = Color4.Color4
type LedDriver = Types.LedDriver

local Prefix = "[LED DRIVER]:"

function led.AddDriver(instance: Led, name: string, registry: DriverRegistry): LedDriver?
    if instance.Type ~= "Led" then
        logWarning(string.format("%s Error while trying to load Driver: Invalid component", Prefix))
        return nil
    end

    local Driver       = setmetatable({}, led) :: any
    Driver.instance    = instance
    Driver._driverData = {
        instance_name = name,
        userdata      = {
					led_color = Color4.FromRGB(0,0,0),
					state = false,
				},
    }

    registry[name] = Driver
    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function led.GetDriver(name: string, registry: DriverRegistry): LedDriver?
    local driver = registry[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function led:SetColor(clr: Color4): ()
		local data = self._driverData.userdata
		data.led_color = clr
end

function led:GetColor(): ()
		local data = self._driverData.userdata
		return data.led_color
end

function led:SetState(state: boolean): ()
		local data = self._driverData.userdata
		
		data.state = state
end

function led:GetState(): ()
		local data = self._driverData.userdata
		
		return data.state
end

function led:_update(): ()
		local instance = self.instance :: Led
		local data = self._driverData.userdata
		local clr = data.led_color:Convert()
		local state = data.state
		
		instance.Color = clr
		instance.State = state
end

return led
