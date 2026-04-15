local Scheduler = {}
Scheduler.__index = Scheduler

local PIDGenerator = require("Utils/PID")
local KernelConfig = require("Config")
local Types = require("Utils/Types")

type Task = Types.Task
type TaskRegistry = Types.TaskRegistry
type TaskConfig   = Types.TaskConfig

local Prefix = KernelConfig.KernelPrefix

function Scheduler.CreateTask(config: TaskConfig, registry: TaskRegistry): Task
    local task = setmetatable({} :: Task, Scheduler)

    task.pid = PIDGenerator.GeneratePID(6)
    task.name = config.name  or "unknown_task"
    task.data = config.Data  or {}
    task.state = "idle"
    task.Update = config.UpdateFunction

    registry[task.pid] = task

    log(string.format("%s %s initialized with pid: %s", Prefix, task.name, task.pid))

    return task
end

function Scheduler.GetTask(pid: string, registry: TaskRegistry): Task?
    local task = registry[pid]
    if not task then
        logWarning(string.format("%s Task with pid %s not found", Prefix, pid))
    end
    return task
end

function Scheduler:SetState(state: "running" | "idle")
    self.state = state
end

function Scheduler:Kill(registry: TaskRegistry)
    if not registry[self.pid] then
        logWarning(string.format("%s %s is not registered in registry", Prefix, self.name))
    else
        registry[self.pid] = nil
        log(string.format("%s %s successfully killed self,pid: %s", Prefix, self.name,self.pid))
    end

    setmetatable(self, nil)
    table.clear(self)
end

return Scheduler
