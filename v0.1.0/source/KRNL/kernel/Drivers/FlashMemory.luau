local flash_memory = {}
flash_memory.__index = flash_memory

local Types  = require("/KRNL/kernel/Utils/Types")
local SizeConverter = require("/KRNL/kernel/Utils/SizeConverter")
local Codec = require("/KRNL/kernel/Utils/Codec")

local Prefix = "[FLASHMEMORY DRIVER]:"

type DriverRegistry = Types.DriverRegistry
type FlashMemoryDriver = Types.FlashMemoryDriver

function flash_memory.AddDriver(instance: FlashMemory, name: string, registry: DriverRegistry): FlashMemoryDriver?
    if instance.Type ~= "FlashMemory" then
        logWarning(string.format("%s Invalid component: %s", Prefix, name))
        return nil
    end

    local Driver       = setmetatable({}, flash_memory) :: any
    Driver.instance    = instance
    Driver._driverData = {
        instance_name = name,
    }

    registry[name] = Driver
    log(string.format("%s Loaded %s driver", Prefix, name))
    return Driver
end

function flash_memory.GetDriver(name: string, registry: DriverRegistry): FlashMemoryDriver?
    local driver = registry[name]
    if not driver then
        logWarning(string.format("%s Driver %s not found", Prefix, name))
    end
    return driver
end

function flash_memory:GetUsage(): number
		local instance : FlashMemory = self.instance
		local usage = instance.Usage
		local size = instance.Size
		
		local ratio = usage / size * 100
		
		local converted_usage = SizeConverter.FormatSize(usage)
		return usage,converted_usage,ratio
end

function flash_memory:GetSize(): any
		local instance : FlashMemory = self.instance
		local size = instance.Size
		
		local converted_size = SizeConverter.FormatSize(size)
		return size,converted_size
end

function flash_memory:Save(data: {any}) : ()
		if typeof(data) ~= "table" then
				logWarning(string.format("%s Data overwrite canceled.Expected type 'table', got '%s'",Prefix,typeof(data)))
				return false
		end
		
		local instance: FlashMemory = self.instance
		local driver_data = self._driverData
		
		local instance_name = driver_data.instance_name
		
		local compressed_result = {Codec.Encode(data)}
		if memory.size(compressed_result) >= instance.Size then
				logWarning(string.format("%s Data overwrite canceled.Not enough space on %s",Prefix,instance_name))
				return false
		end
		
		instance:Save(compressed_result)
		log(string.format("%s Succesfully overwrite data",Prefix))
		
		return true
end

function flash_memory:Load(): {any}
    local instance: FlashMemory = self.instance
    local data = instance:Load()
		
    if not data or #data == 0 then
        log(string.format("%s Storage is empty, returning empty table", Prefix))
        return {} 
    end
    
    local decoded_data = Codec.Decode(data[1])
    return decoded_data or {}
end

return flash_memory
