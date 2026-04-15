-- Better Events - Simple library with type definition (analogue of Roblox RBXScriptSignal)
local BetterEvents = {}
BetterEvents.__index = BetterEvents

type callback = (...any) -> any
type Connection = {
	id: number,
	_connected: boolean,
	callback: callback,
	Disconnect: (...any) -> ()
}
type Signal = {
	__index: {any},
	_connections: {Connection},
	_name: string,
	_active: boolean,
	Fire: (...any) -> (),
	Connect: (callback) -> Connection?,
	Once: (callback) -> Connection?,
	Disable: () -> ()
}

local prefix = "[BETTER EVENTS]"
local Signals = {}
local local_id = 1

-- Creates a new signal with the given name.
-- Returns the Signal object or nil if the name is invalid or already taken.
function BetterEvents.new(name: string) : Signal?
		if not name or typeof(name) ~= "string" or Signals[name] then
				print(string.format("%s Error while trying to create signal: Invalid or taken name of signal",prefix))
				return
		end
		local Signal = setmetatable({},BetterEvents)
		Signal._connections = {}
		Signal._name = name
		Signal._active = true
		
		Signals[name] = Signal
		
		return Signal
end

-- Connects a callback function to the signal.
-- Returns a Connection object which can be used to disconnect the callback.
-- The callback will be called every time the signal is fired until disconnected.
function BetterEvents:Connect(fn: callback) : Connection?
		if not self._connections then
				print(string.format("%s Error while trying to connect callback to signal: Invalid signal instance",prefix))
				return
		end
		local connection = {}
		connection.id = local_id + 1
		connection._connected = true
		connection.callback = fn
		
		-- Disconnects this connection from the signal.
		-- Once disconnected, the callback will no longer be called.
		connection.Disconnect = function()
				if not connection._connected then
						return
				end
				
				connection._connected = false
				
				local remove_index = table.find(self._connections,connection)
				if remove_index then
						table.remove(self._connections,remove_index)
				end
		end
		
		table.insert(self._connections,connection)
		local_id += 1
		
		return connection
end

-- Connects a callback function to the signal that will run only once.
-- After the first call, the connection automatically disconnects.
-- Returns the Connection object.
function BetterEvents:Once(fn: callback) : Connection?
    local connection
    connection = self:Connect(function(...)
        fn(...)
				
        if connection then
            connection:Disconnect()
        end
    end)
		
    return connection
end

-- Fires all connected callbacks with the provided arguments.
-- Does nothing if there are no connections.
function BetterEvents:Fire(...) : ()
		if not self._active then
				return
		end
		
		if not self._connections then
				print(string.format("%s Error while trying to fire all connections: Invalid signal instance",prefix))
				return
		end
		
		if #self._connections <= 0 then
				return
		end
		
		for _,conn: Connection in {table.unpack(self._connections)} do
				conn.callback(...)
		end
end

-- Fires a specific connection by its ID with the provided arguments.
-- Does nothing if the ID is invalid or the connection does not exist.
function BetterEvents:FireSpecificID(id: number,...) : ()
		if not self._connections then
				print(string.format("%s Error while trying to fire specific connection: Invalid signal instance",prefix))
				return
		end
		
		if not id or typeof(id) ~= "number" then
				print(string.format("%s Error while trying to fire specific connection: Invalid connection id",prefix))
				return
		end
		
		if #self._connections <= 0 then
				return
		end
		
		local fn
		
		for _,connection: Connection in self._connections do
				if connection.id == id then fn = connection.callback end
		end
		
		if fn then
				fn(...)
		end
end

-- Disconnects all connections and removes the signal from the global registry.
-- After calling Disable, the signal becomes inactive.
function BetterEvents:Disable() : ()
		if not self._active then
				return
		end
		self._active = false
		
		for _,connection: Connection in self._connections do
				connection:Disconnect()
		end
		
		Signals[self._name] = nil
		self._connections = nil
end

-- Retrieves a signal by name from the global registry.
-- Returns the Signal object or nil if it does not exist.
function BetterEvents.Get(name: string) : Signal?
		if not name or typeof(name) ~= "string" then
				print(string.format("%s Error while trying to get signal: Invalid name of signal",prefix))
				return
		end
		
		local Signal = Signals[name]
		
		if Signal then
				return Signal
		end
		
		return nil
end

return BetterEvents
