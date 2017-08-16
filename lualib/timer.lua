local c = require "ltoy"
local netpack = require "netpack"
local toy = require "toy"

local M = {}

local session = 0
local timer_cbs = {}
function M.timeout(ti, func)
    session = session + 1
    if session >= (1<<31) then
        session = 1
    end
    c.timeout(ti, session)
    timer_cbs[session] = func
    return session
end

function M.remove_timer(session)
    timer_cbs[session] = nil
end

toy.register_protocol {
    id = toy.PTYPE_TIMER,
    name = "timer",
    unpack = function (session, msg, sz )
        return session
    end,
    dispatch = function (session)
        local func = timer_cbs[session]
        if func then
            timer_cbs[session] = nil
            func()
        end
    end
}

return M