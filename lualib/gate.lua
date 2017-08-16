local netpack = require "netpack"
local socketdriver = require "socketdriver"
local toy = require "toy"
local queue     -- message queue
local CMD = setmetatable({}, { __gc = function() 
    netpack.clear(queue)
end })

function CMD.open(conf)
    local address = conf.address or "0.0.0.0"
    local port = assert(conf.port)
    print(string.format("====Listen on %s:%d start====", address, port))
    socket = socketdriver.listen(address, port, conf.opaque)
    socketdriver.start(socket, conf.opaque)
    print(string.format("====Listen on %s:%d end====", address, port))
    return socket
end

function CMD.close(socket, opaque)
    assert(socket)
    socketdriver.close(socket, opaque)
end

local sockmsg_hooks = {}

local function handle_socket_msg(type, opaque, ...)
    local f = sockmsg_hooks[opaque]
    if f then
        f(type, ...)
    end
end

local MSG = {}

function CMD.set_sockmsg_hook(opaque, f)
    sockmsg_hooks[opaque] = f
end

local function dispatch_msg(opaque, fd, msg, sz)
    local data = netpack.tostring(msg, sz)
    handle_socket_msg("data", opaque, fd, data)
end

MSG.data = dispatch_msg

local function dispatch_queue(opaque)
    local fd, msg, sz = netpack.pop(queue)
    if fd then
        -- may dispatch even the handler.message blocked
        -- If the handler.message never block, the queue should be empty, so only fork once and then exit.
        dispatch_msg(opaque, fd, msg, sz)

        for fd, msg, sz in netpack.pop, queue do
            dispatch_msg(opaque, fd, msg, sz)
        end
    end
end

MSG.more = dispatch_queue

function MSG.open(opaque, fd, msg)
    socketdriver.start(fd, opaque)
    socketdriver.nodelay(fd)
    handle_socket_msg("open", opaque, fd)
end

function MSG.close(opaque, fd)
    handle_socket_msg("close", opaque, fd)
end

function MSG.error(opaque, fd, msg)
    handle_socket_msg("error", opaque, fd)
end

function MSG.connect(opaque, fd)
    handle_socket_msg("connect", opaque, fd)
end

toy.register_protocol {
    id = toy.PTYPE_SOCKET,
    name = "socket",
    unpack = function (opaque, msg, sz )
        return opaque,netpack.filter( queue, msg, sz)
    end,
    dispatch = function (opaque, q, type, ...)
        queue = q
        if type then
            MSG[type](opaque, ...)
        end
    end
}

return CMD