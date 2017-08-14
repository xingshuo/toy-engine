local c = require "ltoy"
local toy = {
    PTYPE_SOCKET = 1,
    PTYPE_TIMER = 2,
}

local proto = {}

function toy.register_protocol(class)
    local id = class.id
    assert(proto[id]==nil)
    proto[id] = class
end

function toy.dispatch_message(prototype, msg, sz)
    local p = proto[prototype]
    if p then
        local f = p.dispatch
        if f then
            f(p.unpack(msg,sz))
        end
    end
end

function toy.start()
    c.callback(toy.dispatch_message)
end

function toy.setenv(key, value)
    c.setenv(key, value)
end

function toy.getenv(key)
    return c.getenv(key)
end

return toy