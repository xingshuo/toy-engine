local socketdriver = require "socketdriver"
local gate = require "gate"
local toy = require "toy"
local timer = require "timer"
local netpack = require "netpack"
local const = require "const"
local utils = require "utils"

local sfmt = string.format 

local function netsend(fd, sender, msg)
    msg = sfmt([[{"sender":%d,"msg":"%s","self":%d}]],sender,msg,fd)
    local data = string.pack('>s2', msg)
    socketdriver.send(fd, data)
end

local chat_member = {}
chat_member.__index = chat_member

function chat_member:new(cfg)
    local o = {}
    setmetatable(o, self)
    o:init(cfg)
    return o
end

function chat_member:init( cfg )
    self.id = cfg.fd
    self.fd = cfg.fd
end

function chat_member:quit()

end

local chat_group = {}
chat_group.__index = chat_group

function chat_group:new()
    local o = {}
    setmetatable(o, self)
    o:init()
    return o
end

function chat_group:init()
    self.members = {}
    local tick = 0
    local f
    f = function ()
        tick = tick + 1
        print(sfmt("%d Players In ChatRoom",self:member_size()))
        self:broadcast(0,  "server tick " .. tick)
        timer.timeout(5*100, f)
    end
    timer.timeout(5*100, f)
end

function chat_group:add_member(o_mem)
    self.members[o_mem.id] = o_mem
    self:broadcast(0, sfmt("Player[%d] enter",o_mem.id))
end

function chat_group:del_member(mem_id)
    if self.members[mem_id] then
        local o_mem = self.members[mem_id]
        self.members[mem_id] = nil
        self:broadcast(0, sfmt("Player[%d] quit",mem_id) )
        o_mem:quit()
    end
end

function chat_group:member_chat(mem_id, msg)
    if self.members[mem_id] then
        self:broadcast(mem_id,  msg)
    end
end

function chat_group:broadcast(sender,  msg)
    for mid,o_mem in pairs(self.members) do
        netsend(o_mem.fd, sender, msg)
    end
end

function chat_group:member_size()
    return utils.table_len(self.members)
end

g_ChatMgr = chat_group:new()

gate.set_sockmsg_hook(const.SOCK_OPAQUE_CLIENT, function (type, ...)
    local fd = ...
    if type == "open" then
        local o_mem = chat_member:new({fd = fd})
        g_ChatMgr:add_member(o_mem)
    elseif type == "close" then
        g_ChatMgr:del_member(fd)
    elseif type == "data" then
        local data = select(2,...)
        g_ChatMgr:member_chat(fd, data)
    end
end)

