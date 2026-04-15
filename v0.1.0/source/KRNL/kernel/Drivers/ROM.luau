local rom = {}
rom.__index = rom

local KernelConfig = require("/KRNL/kernel/Config")
local Types        = require("/KRNL/kernel/Utils/Types")

type DriverRegistry = Types.DriverRegistry
type RomDriver = Types.RomDriver

local Prefix = "[ROM DRIVER]:"

function rom.AddDriver(instance: ROM, name: string, registry: DriverRegistry) : RomDriver?
    if instance.Type ~= "ROM" then
        logWarning(string.format("%s Error while trying to load Driver: Invalid component", Prefix))
        return nil
    end

    local Driver = setmetatable({}, rom) :: any
    Driver.instance = instance
    Driver._driverData = {
        instance_name = name,
        userdata = {},
    }

    registry[name] = Driver
    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function rom.GetDriver(name: string, registry: DriverRegistry): RomDriver?
    local driver = registry[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function rom:GetSprite(name: string) : SpriteSheet
    local asset = self.instance.User.SpriteSheets[name]
    if not asset then
        logWarning(string.format("%s SpriteSheet '%s' not found in User assets", Prefix, name))
    end
    return asset
end

function rom:GetSystemSprite(name: string) : SpriteSheet
    local asset = self.instance.System.SpriteSheets[name]
    if not asset then
        logWarning(string.format("%s SpriteSheet '%s' not found in System assets", Prefix, name))
    end
    return asset
end

function rom:GetStandardFont() : SpriteSheet
    return self.instance.System.SpriteSheets["StandardFont"]
end

function rom:GetAudio(name: string) : AudioSample
    local asset = self.instance.User.AudioSamples[name]
    if not asset then
        logWarning(string.format("%s AudioSample '%s' not found in User assets", Prefix, name))
    end
    return asset
end

function rom:GetSystemAudio(name: string) : AudioSample
    local asset = self.instance.System.AudioSamples[name]
    if not asset then
        logWarning(string.format("%s AudioSample '%s' not found in System assets", Prefix, name))
    end
    return asset
end

function rom:GetCode(name: string): Code
    local asset = self.instance.User.Codes[name]
    if not asset then
        logWarning(string.format("%s Code '%s' not found in User assets", Prefix, name))
    end
    return asset
end

function rom:GetAsset(name: string): any
    local asset = self.instance.User.Assets[name]
    if not asset then
        logWarning(string.format("%s Asset '%s' not found in User assets", Prefix, name))
    end
    return asset
end

function rom:ListAssets(): { string }
    local names = {}
    for name, _ in self.instance.User.Assets do
        table.insert(names, name)
    end
    return names
end

function rom:ListSprites(): { string }
    local names = {}
    for name, _ in self.instance.User.SpriteSheets do
        table.insert(names, name)
    end
    return names
end

function rom:ListAudio(): { string }
    local names = {}
    for name, _ in self.instance.User.AudioSamples do
        table.insert(names, name)
    end
    return names
end

function rom:_update() : ()
		
end

return rom
