local PIDGenerator = {}

local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

function PIDGenerator.GeneratePID(length: number): string
    local pid = {}
    for i = 1, length do
        local index = math.random(1, #charset)
        pid[i] = charset:sub(index, index)
    end
    return table.concat(pid)
end

return PIDGenerator
