local slider = {}
slider.__index = slider

local KernelConfig = require("/KRNL/kernel/Config")
local Types = require("/KRNL/kernel/Utils/Types")
local BetterEvents = require("/KRNL/kernel/Utils/BetterEvents")
local Color4 = require("/KRNL/kernel/Utils/Color4")

type DriverRegistry = Types.DriverRegistry
type Color4 = Color4.Color4
type SwitchDriver = Types.SwitchDriver

local Prefix = "[SLIDER DRIVER]:"

function slider.AddDriver(instance: Slider, name: string, registry: DriverRegistry): SwitchDriver?
    if instance.Type ~= "Slider" then
        logWarning(string.format("%s Error while trying to load Driver: Invalid component", Prefix))
        return nil
    end
		
    local Driver = setmetatable({}, slider) :: any
    Driver.instance = instance
    Driver._driverData = {
        instance_name = name,
        userdata = {
           value = 0,
        },
    }
		
    Driver.ValueChanged = BetterEvents.new(name .. "_valuechanged")

    registry[name] = Driver
    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function slider.GetDriver(name: string, registry: DriverRegistry): SwitchDriver?
    local driver = registry[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function slider:SetValue(value: number): ()
		local instance = self.instance :: Slider
		
		instance.Value = value
end

function slider:GetValue(value: boolean): number
		local data = self._driverData.userdata
		
		return data.value
end

function slider:IsMoving(): boolean
		local instance = self.instance :: Slider
		
		return instance.IsMoving
end

function slider:_update(): ()
		local data = self._driverData.userdata
		local instance = self.instance :: Slider
		
		if instance.Value ~= data.value then
				self.ValueChanged:Fire()
		end
		
		data.value = instance.Value
end

return slider
