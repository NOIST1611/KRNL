local Keyboard = {}
Keyboard.__index = Keyboard

local Prefix       = "[KEYBOARD DRIVER]:"
local Types        = require("/KRNL/kernel/Utils/Types")
local BetterEvents = require("/KRNL/kernel/Utils/BetterEvents")

type DriverRegistry = Types.DriverRegistry
type KeyboardDriver = Types.KeyboardDriver

local SPECIAL_KEYS = {
    ["Space"]     = " ",
    ["Period"]    = ".",
    ["Comma"]     = ",",
    ["Semicolon"] = ";",
    ["Quote"]     = "'",
    ["DoubleQuote"] = "\"",
    ["Question"]  = "?",
    ["Exclamation"] = "!",
		
		["Alpha0"] = "0",
		["Alpha1"] = "1",
		["Alpha2"] = "2",
		["Alpha3"] = "3",
		["Alpha4"] = "4",
		["Alpha5"] = "5",
		["Alpha6"] = "6",
		["Alpha7"] = "7",
		["Alpha8"] = "8",
		["Alpha9"] = "9",
		
    ["Equals"]      = "=",
    ["Plus"]        = "+",
    ["Minus"]       = "-",
    ["Asterisk"]    = "*",
    ["Slash"]       = "/",
    ["Backslash"]   = "\\",
    ["Percent"]     = "%",
    ["Ampersand"]   = "&",
    ["At"]          = "@",
    ["Hash"]        = "#",
    ["Dollar"]      = "$",
    ["Caret"]       = "^",
    ["Underscore"]  = "_",
		
    ["LeftParen"]   = "(",
    ["RightParen"]  = ")",
    ["LeftBracket"] = "[",
    ["RightBracket"] = "]",
    ["LeftBrace"]   = "{",
    ["RightBrace"]  = "}",
    ["Less"]        = "<",
    ["Greater"]     = ">",
    ["Grave"]       = "`",
}

function Keyboard.AddDriver(instance: KeyboardChip, name: string, registry: DriverRegistry): KeyboardDriver?
    if instance.Type ~= "KeyboardChip" then
        logWarning(string.format("%s Invalid component: %s", Prefix, name))
        return nil
    end

    local Driver       = setmetatable({}, Keyboard) :: any
    Driver.instance    = instance
    Driver._driverData = {
        instance_name = name,
        userdata = {
            buffer        = "",
            held_keys     = {},
            buffer_limit  = 64,
            event_function = function(sender, event: KeyboardChipEvent)
                local key = tostring(event.InputName)
                if event.ButtonDown then
                    Driver._driverData.userdata.held_keys[key] = true
                    Driver.InputBegan:Fire(key)
                    Driver:_handleBuffer(key)
                else
                    Driver._driverData.userdata.held_keys[key] = nil
                    Driver.InputEnded:Fire(key)
                end
            end
        },
    }
		
    Driver.InputBegan    = BetterEvents.new(name .. "_inputbegan")
    Driver.InputEnded    = BetterEvents.new(name .. "_inputended")
    Driver.BufferChanged = BetterEvents.new(name .. "_bufferchanged")
    Driver.BufferSubmit  = BetterEvents.new(name .. "_buffersubmit")

    registry[name] = Driver
    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function Keyboard.GetDriver(name: string, registry: DriverRegistry) : KeyboardDriver?
    local driver = registry[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function Keyboard:_handleBuffer(key: string) : ()
    local data  = self._driverData.userdata
    local limit = data.buffer_limit

    if key == "Return" then
        self.BufferSubmit:Fire(data.buffer)
        data.buffer = ""
        self.BufferChanged:Fire(data.buffer)
        return
    end

    if key == "Backspace" then
        if #data.buffer > 0 then
            data.buffer = data.buffer:sub(1, -2)
            self.BufferChanged:Fire(data.buffer)
        end
        return
    end

    if #data.buffer >= limit then return end

    local char = nil

    if SPECIAL_KEYS[key] then
        char = SPECIAL_KEYS[key]
    elseif #key == 1 then
        local shift = data.held_keys["LeftShift"] or data.held_keys["RightShift"]
        char = shift and key:upper() or key:lower()
    end

    if char then
        data.buffer = data.buffer .. char
        self.BufferChanged:Fire(data.buffer)
    end
end

function Keyboard:GetBuffer(): string
    return self._driverData.userdata.buffer
end

function Keyboard:Flush(): ()
    self._driverData.userdata.buffer = ""
    self.BufferChanged:Fire("")
end

function Keyboard:IsKeyHeld(key: string): boolean
    return self._driverData.userdata.held_keys[key] == true
end

function Keyboard:SetBufferLimit(limit: number): ()
    self._driverData.userdata.buffer_limit = limit
end

function Keyboard:HookEventChannel() : any
    return self._driverData.userdata.event_function
end

function Keyboard:_update(): ()
		
end

return Keyboard
