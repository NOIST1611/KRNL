local reality = {}
reality.__index = reality

local Types  = require("/KRNL/kernel/Utils/Types")
local Prefix = "[REALITY DRIVER]:"

type DriverRegistry = Types.DriverRegistry
type RealityDriver = Types.RealityDriver

function reality.AddDriver(instance: RealityChip, name: string, registry: DriverRegistry): RealityDriver?
    if instance.Type ~= "RealityChip" then
        logWarning(string.format("%s Invalid component: %s", Prefix, name))
        return nil
    end

    local Driver       = setmetatable({}, reality) :: any
    Driver.instance    = instance
    Driver._driverData = {
        instance_name = name,
        userdata      = {},
    }

    registry[name] = Driver
    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function reality.GetDriver(name: string, registry: DriverRegistry): RealityDriver?
    local driver = registry[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function reality:GetCPUUsage(): number
    return self.instance.Cpu.TotalUsage
end

function reality:GetCPUCoresUsage(): { number }
    return self.instance.Cpu.CoresUsage
end

function reality:GetRAMAvailable(): number
    return self.instance.Ram.Available
end

function reality:GetRAMUsed(): number
    return self.instance.Ram.Used
end

function reality:GetRAMTotal(): number
    return self.instance.Ram.Available + self.instance.Ram.Used
end

function reality:GetNetworkSent(): number
    return self.instance.Network.TotalSent
end

function reality:GetNetworkReceived(): number
    return self.instance.Network.TotalReceived
end

function reality:GetDateTime() : any
    return self.instance:GetDateTime()
end

function reality:GetDateTimeUTC() : any
    return self.instance:GetDateTimeUTC()
end

function reality:GetTimeString(): string
    local dt = self.instance:GetDateTime()
    return string.format("%02d:%02d:%02d", dt.hour, dt.min, dt.sec)
end

function reality:GetDateString(): string
    local dt = self.instance:GetDateTime()
    return string.format("%02d/%02d/%04d", dt.day, dt.month, dt.year)
end

function reality:GetFullDateTimeString(): string
    return self:GetTimeString() .. " " .. self:GetDateString()
end

function reality:LoadSprite(filename: string, sw: number, sh: number) : SpriteSheet
    return self.instance:LoadSpriteSheet(filename, sw, sh)
end

function reality:LoadAudio(filename: string): AudioSample
    return self.instance:LoadAudioSample(filename)
end

function reality:UnloadAsset(filename: string): ()
    self.instance:UnloadAsset(filename)
end

function reality:ListDir(directory: string): { string }
    return self.instance:ListDirectory(directory)
end

function reality:GetFileMeta(filename: string): any
    return self.instance:GetFileMetadata(filename)
end

function reality:_update() : ()
		
end

return reality
