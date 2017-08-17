local socketdriver = require "socketdriver"
local ltoy = require "ltoy"
local toy = require "toy"
local gate = require "gate"
local const = require "const"
local utils = require "utils"
local sfmt = string.format 

local M = {}

local cluster_cbs = {}

local message_handlers = {}

function M.reg_msg_handler(reg_tbl)
    for k,v in pairs(reg_tbl) do
        message_handlers[k] = v
    end
end

local node_address = {}
local session = 0

local function alloct_session()
    session = session + 1
    if session >= (1<<31) then
        session = 1
    end
    return session
end

local conn_map = {}
local connection = {}
connection.__index = connection

local function open_channel(t, key)
    local c = connection:new(key)
    t[key] = c
    return c
end

local node_channel = setmetatable({}, { __index = open_channel })

function connection:new(dest_cluster)
    local o = {}
    setmetatable(o, self)
    o:init(dest_cluster)
    return o
end

function connection:init(dest_cluster)
    self.dest_cluster = dest_cluster
    local host, port = string.match(node_address[dest_cluster], "([^:]+):(.*)$")
    self.status = 0
    self.fd = socketdriver.connect(host, port, const.SOCK_OPAQUE_CLUSTER)
    conn_map[self.fd] = self
    self.msg_queue = {}
end

function connection:is_connected()
    return self.status == 1
end

function connection:connected()
    self.status = 1
    for _,data in pairs(self.msg_queue) do
        self:send(data)
    end
    self.msg_queue = {}
end

function connection:push(data)
    table.insert(self.msg_queue, data)
end

function connection:send(data)
    data = ltoy.packstring(table.unpack(data))
    local pkg = string.pack('>s2', data)
    socketdriver.send(self.fd, pkg)
end

function connection:release()
    conn_map[self.fd] = nil
    node_channel[self.dest_cluster] = nil
end


function M.loadconfig(config_name)
    local f = assert(io.open(config_name))
    local source = f:read "*a"
    f:close()
    local tmp = {}
    assert(load(source, "@"..config_name, "t", tmp))()
    for name,address in pairs(tmp) do
        assert(type(address) == "string")
        if node_address[name] ~= address then
            -- address changed
            if rawget(node_channel, name) then
                local c = node_channel[name]    -- reset connection
                c:release()
            end
            node_address[name] = address
        end
    end
end
--response request
local function do_send(dest_cluster, session, cmd, ...)
    local c = node_channel[dest_cluster]
    if c:is_connected() then
        c:send({'req',M.clustername(),session,cmd,...})
    else
        c:push({'req',M.clustername(),session,cmd,...})
    end
end

function M.send(dest_cluster, cmd, ...)
    do_send(dest_cluster, 0, cmd, ...)
end

function M.call(cb, dest_cluster, cmd, ... )
    local session = alloct_session()
    do_send(dest_cluster, session, cmd, ...)
    cluster_cbs[session] = cb
end

function M.clustername()
    return toy.getenv("clustername")
end

local function handle_cluster_msg(fd, head, source, session, cmd, ... )
    if head == 'req' then
        local f = message_handlers[cmd]
        if f then
            if session == 0 then --send
                f(source, ...)
            else
                local ret = {f(source, ...)}
                local data = {'resp', M.clustername(), session, cmd}
                table.move(ret,1,#ret,#data+1,data)
                data = ltoy.packstring(table.unpack(data))
                local pkg = string.pack('>s2', data)
                socketdriver.send(fd, pkg)
            end
        else
            print(sfmt("Unknow cluster req cmd %s", cmd))
        end
    elseif head == "resp" then
        local cb = cluster_cbs[session]
        if cb then
            cb(source, ...)
        else
            print(sfmt("Unknow cluster resp cmd %s", cmd))
        end
    end
end

gate.set_sockmsg_hook(const.SOCK_OPAQUE_CLUSTER, function (type, ...)
    local fd = ...
    if type == "connect" then
        local c = conn_map[fd]
        if c then
            c:connected()
        end
    elseif type == "close" or type == "error" then
        local c = conn_map[fd]
        if c then
            c:release()
        end
    elseif type == "data" then
        local msg,sz = select(2,...)
        handle_cluster_msg(fd, ltoy.unpack(msg,sz))
    end
end)

return M