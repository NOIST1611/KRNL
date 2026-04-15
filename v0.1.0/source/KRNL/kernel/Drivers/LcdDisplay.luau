local Lcd = {}
Lcd.__index = Lcd

local Prefix = "[LCD DRIVER]:"

local Types = require("/KRNL/kernel/Utils/Types")
local Color4 = require("/KRNL/kernel/Utils/Color4")

type DriverRegistry = Types.DriverRegistry
type Color4 = Color4.Color4
type LcdDriver = Types.LcdDriver

function Lcd.AddDriver(instance: LcdDisplay, name: string, registry: DriverRegistry): LcdDriver?
    if instance.Type ~= "LcdDisplay" then
        logWarning(string.format("%s Invalid component for LCD: %s", Prefix, name))
        return
    end

    local driver = setmetatable({}, Lcd)
    driver.instance = instance
		
    driver._driverData = {
        instance_name = name,
        userdata = {
            bg_color = Color4.FromRGB(0, 0, 0),
            text_color = Color4.FromRGB(255, 255, 255),
        }
    }

    registry[name] = driver
		
    driver.instance.BgColor = driver._driverData.userdata.bg_color:Convert()
    driver.instance.TextColor = driver._driverData.userdata.text_color:Convert()

    log(string.format("%s Loaded %s driver", Prefix, name))
    return driver
end

function Lcd.GetDriver(name: string, registry: DriverRegistry)
    local drv = registry[name]
    if not drv then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return drv
end

function Lcd:SetText(text: string)
    if #text > 32 then
        text = text:sub(1, 32)
    end
    self.instance.Text = text
end

function Lcd:GetText(): string
    return self.instance.Text
end

function Lcd:Clear()
    self:SetText((" "):rep(32))
end

function Lcd:PrintLine(line: number, text: string)
    local t = text:sub(1, 16)
		
    local cur = self:GetText() or ""

    if #cur < 32 then
        cur = cur .. (" "):rep(32 - #cur)
    end

    if line == 1 then
        cur = t .. cur:sub(17, 32)
    elseif line == 2 then
        cur = cur:sub(1, 16) .. t
    else
        logWarning(Prefix .. " Invalid line for PrintLine")
        return
    end

    self:SetText(cur)
end

function Lcd:CenterLine(line: number, text: string): ()
    local len = #text
    local pad = math.max(0, math.floor((16 - len) / 2))
    local centered = (" "):rep(pad) .. text
    self:PrintLine(line, centered)
end

function Lcd:SetTextColor(color: Color4): ()
    self._driverData.userdata.text_color = color
    self.instance.TextColor = color:Convert()
end

function Lcd:SetBackgroundColor(color: Color4): ()
    self._driverData.userdata.bg_color = color
    self.instance.BgColor = color:Convert()
end

function Lcd:GetTextColor(): Color4
    return self._driverData.userdata.text_color
end

function Lcd:GetBackgroundColor(): Color4
    return self._driverData.userdata.bg_color
end

function Lcd:_update() : ()
		
end

return Lcd
