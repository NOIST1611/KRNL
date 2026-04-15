local SizeConverter = {}

function SizeConverter.FormatSize(bytes)
    local units = {"B", "KB", "MB", "GB", "TB"}
    
    if bytes <= 0 then return "0 B" end
		
    local i = math.floor(math.log(bytes) / math.log(1024))
		
    i = math.min(i, #units - 1)
    
    local value = bytes / (1024 ^ i)
		
    return string.format("%.2f %s", value, units[i + 1])
end

return SizeConverter
