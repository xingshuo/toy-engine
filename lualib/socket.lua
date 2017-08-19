local driver = require "socketdriver"
local toy = require "toy"
local assert = assert

local socket = {}	-- api
local buffer_pool = {}	-- store all message buffer object
local socket_pool = setmetatable( -- store all socket object
	{},
	{ __gc = function(p)
		for id,v in pairs(p) do
			driver.close(id, p.opaque)
			-- don't need clear v.buffer, because buffer pool will be free at the end
			p[id] = nil
		end
	end
	}
)

local socket_message = {}

local function wakeup(s)
	local co = s.co
	if co then
		s.co = nil
		toy.wakeup(co)
	end
end

local function suspend(s)
	assert(not s.co)
	s.co = coroutine.running()
	toy.wait(s.co)
	-- wakeup closing corouting every time suspend,
	-- because socket.close() will wait last socket buffer operation before clear the buffer.
	if s.closing then
		toy.wakeup(s.closing)
	end
end

-- read toy_socket.h for these macro
-- toy_SOCKET_TYPE_DATA = 1
socket_message[1] = function(id, size, data)
	local s = socket_pool[id]
	if s == nil then
		toy.error("socket: drop package from " .. id)
		driver.drop(data, size)
		return
	end

	local sz = driver.push(s.buffer, buffer_pool, data, size)
	local rr = s.read_required
	local rrt = type(rr)
	if rrt == "number" then
		-- read size
		if sz >= rr then
			s.read_required = nil
			wakeup(s)
		end
	else
		if s.buffer_limit and sz > s.buffer_limit then
			toy.error(string.format("socket buffer overflow: fd=%d size=%d", id , sz))
			driver.clear(s.buffer,buffer_pool)
			driver.close(id, s.opaque)
			return
		end
		if rrt == "string" then
			-- read line
			if driver.readline(s.buffer,nil,rr) then
				s.read_required = nil
				wakeup(s)
			end
		end
	end
end

-- TOY_SOCKET_TYPE_CONNECT = 2
socket_message[2] = function(id, _ , addr)
	local s = socket_pool[id]
	if s == nil then
		return
	end
	-- log remote addr
	s.connected = true
	wakeup(s)
end

-- TOY_SOCKET_TYPE_CLOSE = 3
socket_message[3] = function(id)
	local s = socket_pool[id]
	if s == nil then
		return
	end
	s.connected = false
	wakeup(s)
end

-- TOY_SOCKET_TYPE_ACCEPT = 4
socket_message[4] = function(id, newid, addr)
	local s = socket_pool[id]
	if s == nil then
		driver.close(newid, 0)
		return
	end
	s.callback(newid, addr)
end

-- TOY_SOCKET_TYPE_ERROR = 5
socket_message[5] = function(id, _, err)
	local s = socket_pool[id]
	if s == nil then
		toy.error("socket: error on unknown", id, err)
		return
	end
	if s.connected then
		toy.error("socket: error on", id, err)
	elseif s.connecting then
		s.connecting = err
	end
	s.connected = false
	driver.shutdown(id, s.opaque)

	wakeup(s)
end

local function default_warning(id, size)
	local s = socket_pool[id]
	if not s then
		return
	end
	toy.error(string.format("WARNING: %d K bytes need to send out (fd = %d)", size, id))
end

-- TOY_SOCKET_TYPE_WARNING
socket_message[7] = function(id, size)
	local s = socket_pool[id]
	if s then
		local warning = s.on_warning or default_warning
		warning(id, size)
	end
end

function socket.register(opaque)
	toy.register_socket_protocol {
		opaque = opaque,
		unpack = driver.unpack,
		dispatch = function (opaque, t, ...)
			socket_message[t](...)
		end
	}
end

local function connect(id, opaque, func)
	local newbuffer
	if func == nil then
		newbuffer = driver.buffer()
	end
	local s = {
		id = id,
		buffer = newbuffer,
		connected = false,
		connecting = true,
		read_required = false,
		co = false,
		callback = func,
		protocol = "TCP",
		opaque = opaque,
	}
	assert(not socket_pool[id], "socket is not closed")
	socket_pool[id] = s
	suspend(s)
	local err = s.connecting
	s.connecting = nil
	if s.connected then
		return id
	else
		socket_pool[id] = nil
		return nil, err
	end
end

function socket.open(addr, port, opaque)
	local id = driver.connect(addr,port,opaque)
	return connect(id, opaque)
end

function socket.start(id, opaque, func)
	driver.start(id, opaque)
	return connect(id, opaque, func)
end

local function close_fd(id, func)
	local s = socket_pool[id]
	if s then
		if s.buffer then
			driver.clear(s.buffer,buffer_pool)
		end
		if s.connected then
			func(id, s.opaque)
		end
	end
end

function socket.shutdown(id)
	close_fd(id, driver.shutdown)
end

function socket.close_fd(id, opaque)
	assert(socket_pool[id] == nil,"Use socket.close instead")
	driver.close(id, opaque)
end

function socket.close(id)
	local s = socket_pool[id]
	if s == nil then
		return
	end
	if s.connected then
		driver.close(id, s.opaque)
		-- notice: call socket.close in __gc should be carefully,
		-- because toy.wait never return in __gc, so driver.clear may not be called
		if s.co then
			-- reading this socket on another coroutine, so don't shutdown (clear the buffer) immediately
			-- wait reading coroutine read the buffer.
			assert(not s.closing)
			s.closing = coroutine.running()
			toy.wait(s.closing)
		else
			suspend(s)
		end
		s.connected = false
	end
	close_fd(id)	-- clear the buffer (already close fd)
	assert(s.lock == nil or next(s.lock) == nil)
	socket_pool[id] = nil
end

function socket.read(id, sz)
	local s = socket_pool[id]
	assert(s)
	if sz == nil then
		-- read some bytes
		local ret = driver.readall(s.buffer, buffer_pool)
		if ret ~= "" then
			return ret
		end

		if not s.connected then
			return false, ret
		end
		assert(not s.read_required)
		s.read_required = 0
		suspend(s)
		ret = driver.readall(s.buffer, buffer_pool)
		if ret ~= "" then
			return ret
		else
			return false, ret
		end
	end

	local ret = driver.pop(s.buffer, buffer_pool, sz)
	if ret then
		return ret
	end
	if not s.connected then
		return false, driver.readall(s.buffer, buffer_pool)
	end

	assert(not s.read_required)
	s.read_required = sz
	suspend(s)
	ret = driver.pop(s.buffer, buffer_pool, sz)
	if ret then
		return ret
	else
		return false, driver.readall(s.buffer, buffer_pool)
	end
end

function socket.readall(id)
	local s = socket_pool[id]
	assert(s)
	if not s.connected then
		local r = driver.readall(s.buffer, buffer_pool)
		return r ~= "" and r
	end
	assert(not s.read_required)
	s.read_required = true
	suspend(s)
	assert(s.connected == false)
	return driver.readall(s.buffer, buffer_pool)
end

function socket.readline(id, sep)
	sep = sep or "\n"
	local s = socket_pool[id]
	assert(s)
	local ret = driver.readline(s.buffer, buffer_pool, sep)
	if ret then
		return ret
	end
	if not s.connected then
		return false, driver.readall(s.buffer, buffer_pool)
	end
	assert(not s.read_required)
	s.read_required = sep
	suspend(s)
	if s.connected then
		return driver.readline(s.buffer, buffer_pool, sep)
	else
		return false, driver.readall(s.buffer, buffer_pool)
	end
end

function socket.block(id)
	local s = socket_pool[id]
	if not s or not s.connected then
		return false
	end
	assert(not s.read_required)
	s.read_required = 0
	suspend(s)
	return s.connected
end

socket.write = assert(driver.send)
socket.lwrite = assert(driver.lsend)
socket.header = assert(driver.header)

function socket.invalid(id)
	return socket_pool[id] == nil
end

function socket.listen(host, port, opaque, backlog)
	if port == nil then
		host, port = string.match(host, "([^:]+):(.+)$")
		port = tonumber(port)
	end
	return driver.listen(host, port, opaque, backlog)
end

function socket.lock(id)
	local s = socket_pool[id]
	assert(s)
	local lock_set = s.lock
	if not lock_set then
		lock_set = {}
		s.lock = lock_set
	end
	if #lock_set == 0 then
		lock_set[1] = true
	else
		local co = coroutine.running()
		table.insert(lock_set, co)
		toy.wait(co)
	end
end

function socket.unlock(id)
	local s = socket_pool[id]
	assert(s)
	local lock_set = assert(s.lock)
	table.remove(lock_set,1)
	local co = lock_set[1]
	if co then
		toy.wakeup(co)
	end
end

-- abandon use to forward socket id to other service
-- you must call socket.start(id) later in other service
function socket.abandon(id)
	local s = socket_pool[id]
	if s and s.buffer then
		driver.clear(s.buffer,buffer_pool)
	end
	socket_pool[id] = nil
end

function socket.limit(id, limit)
	local s = assert(socket_pool[id])
	s.buffer_limit = limit
end

function socket.warning(id, callback)
	local obj = socket_pool[id]
	assert(obj)
	obj.on_warning = callback
end

return socket
