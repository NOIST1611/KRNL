local ledButton = {}
ledButton.__index = ledButton

local KernelConfig = require("/KRNL/kernel/Config")
local Types = require("/KRNL/kernel/Utils/Types")
local BetterEvents = require("/KRNL/kernel/Utils/BetterEvents")
local Color4 = require("/KRNL/kernel/Utils/Color4")

type DriverRegistry = Types.DriverRegistry
type Color4 = Color4.Color4
type LedButtonDriver = Types.LedButtonDriver

local Prefix = "[LEDBUTTON DRIVER]:"

function ledButton.AddDriver(instance: LedButton, name: string, registry: DriverRegistry): LedButtonDriver?
    if instance.Type ~= "LedButton" then
        logWarning(string.format("%s Error while trying to load Driver: Invalid component", Prefix))
        return nil
    end
		
    local Driver = setmetatable({}, ledButton) :: any
    Driver.instance = instance
    Driver._driverData = {
        instance_name = name,
        userdata = {
            led_color = Color4.FromRGB(0, 0, 0),
            led_state = false,
        },
    }
		
    Driver.OnPressed = BetterEvents.new(name .. "_onpressed")
    Driver.OnReleased = BetterEvents.new(name .. "_onreleased")

    registry[name] = Driver
    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function ledButton.GetDriver(name: string, registry: DriverRegistry): LedButtonDriver?
    local driver = registry[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function ledButton:SetColor(clr: Color4): ()
    self._driverData.userdata.led_color = clr
end

function ledButton:GetColor(): Color4
    return self._driverData.userdata.led_color
end

function ledButton:SetLedState(state: boolean): ()
    self._driverData.userdata.led_state = state
end

function ledButton:GetLedState(): boolean
    return self._driverData.userdata.led_state
end

function ledButton:IsPressed(): boolean
    return self.instance.ButtonState
end

function ledButton:_update(): ()
    local data = self._driverData.userdata
    local instance = self.instance :: LedButton

    instance.LedColor = data.led_color:Convert()
    instance.LedState = data.led_state
		
		if instance.ButtonDown then
				self.OnPressed:Fire()
		elseif instance.ButtonUp then
				self.OnReleased:Fire()
		end
end

return ledButton
