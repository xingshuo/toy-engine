local netpack = require "netpack"
local socketdriver = require "socketdriver"
local toy = require "toy"
local socket    -- listen socket
local queue     -- message queue
local CMD = setmetatable({}, { __gc = function() 
    local netpack = require "netpack"
    netpack.clear(queue)
end })

function CMD.open(conf)
    local address = conf.address or "0.0.0.0"
    local port = assert(conf.port)
    print(string.format("====Listen on %s:%d start====", address, port))
    socket = socketdriver.listen(address, port)
    socketdriver.start(socket)
    print(string.format("====Listen on %s:%d end====", address, port))
end

function CMD.close()
    assert(socket)
    socketdriver.close(socket)
end

local function handle_socket_msg(type, ...)
    -- body
end

local MSG = {}

function CMD.set_sockmsg_hook(f)
    assert(f)
    handle_socket_msg = f
end

local function dispatch_msg(fd, msg, sz)
    local data = netpack.tostring(msg, sz)
    handle_socket_msg("data", fd, data)
end

MSG.data = dispatch_msg

local function dispatch_queue()
    local fd, msg, sz = netpack.pop(queue)
    if fd then
        -- may dispatch even the handler.message blocked
        -- If the handler.message never block, the queue should be empty, so only fork once and then exit.
        dispatch_msg(fd, msg, sz)

        for fd, msg, sz in netpack.pop, queue do
            dispatch_msg(fd, msg, sz)
        end
    end
end

MSG.more = dispatch_queue

function MSG.open(fd, msg)
    socketdriver.start(fd)
    socketdriver.nodelay(fd)
    handle_socket_msg("open", fd)
end

function MSG.close(fd)
    handle_socket_msg("close", fd)
end

function MSG.error(fd, msg)
    handle_socket_msg("error", fd)
end


toy.register_protocol {
    id = toy.PTYPE_SOCKET,
    name = "socket",
    unpack = function ( msg, sz )
        return netpack.filter( queue, msg, sz)
    end,
    dispatch = function (q, type, ...)
        queue = q
        if type then
            MSG[type](...)
        end
    end
}

return CMD