local c = require "ltoy"

local sfmt = string.format 
local coroutine_resume = coroutine.resume 
local coroutine_yield = coroutine.yield 
local coroutine_create = coroutine.create 

local toy = {
    PTYPE_SOCKET = 1,
    PTYPE_TIMER = 2,
}

local proto = {}
local socket_proto = {}

toy.pack = assert(c.pack)
toy.packstring = assert(c.packstring)
toy.unpack = assert(c.unpack)
toy.tostring = assert(c.tostring)
toy.trash = assert(c.trash)

function toy.register_protocol(class)
    local id = class.id
    assert(proto[id]==nil)
    proto[id] = class
end

function toy.register_socket_protocol(class)
    local opaque = class.opaque
    assert(socket_proto[opaque]==nil)
    socket_proto[opaque] = class
end

local coroutine_pool = setmetatable({}, { __mode = "kv" })

local function co_create(f)
    local co = table.remove(coroutine_pool)
    if co == nil then
        co = coroutine_create(function(...)
            f(...)
            while true do
                f = nil
                coroutine_pool[#coroutine_pool+1] = co
                f = coroutine_yield "EXIT"
                f(coroutine_yield())
            end
        end)
    else
        coroutine_resume(co, f)
    end
    return co
end

local co_session = 0
local function genid_co_sin()
    co_session = co_session + 1
    return co_session
end
local session_id_coroutine = {} --debug
local sleep_session = {}
local wakeup_queue = {}
local fork_queue = {}

local function suspend(co, result, command, ...)
    if not result then
        error(debug.traceback(co,tostring(command)))
    end
    if command == "EXIT" then --go well

    elseif command == "SLEEP" then
        local session = ...
        sleep_session[co] = session
        session_id_coroutine[session] = co
    end

    local co = table.remove(wakeup_queue,1)
    if co then
        local session = sleep_session[co]
        if session then
            suspend(co, coroutine_resume(co)) 
        end
    end
end

function toy.dispatch_message(prototype, session, msg, sz)
    local p
    if prototype == toy.PTYPE_SOCKET then
        p = socket_proto[session]
    else
        p = proto[prototype]
    end
    if p then
        local f = p.dispatch
        if f then
            local co = co_create(f)
            suspend(co, coroutine_resume(co, session, p.unpack(msg,sz)))
        end
    end
    while true do
        local key,co = next(fork_queue)
        if co == nil then
            break
        end
        fork_queue[key] = nil
        suspend(co, coroutine_resume(co))
    end
end

function toy.wait(co)
    local session = genid_co_sin()
    coroutine_yield("SLEEP", session)
    co = co or coroutine.running()
    sleep_session[co] = nil
    session_id_coroutine[session] = nil
end

function toy.wakeup(co)
    if sleep_session[co] then
        table.insert(wakeup_queue, co)
        return true
    end
end

function toy.sleep(ti)
    local timer = require "timer"
    local co = coroutine.running()
    timer.timeout(ti, function ()
        toy.wakeup(co)
    end)
    toy.wait(co)
end

function toy.fork(func,...)
    local args = table.pack(...)
    local co = co_create(function()
        func(table.unpack(args,1,args.n))
    end)
    table.insert(fork_queue, co)
    return co
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

function toy.error( ... )
    print(...)
end

function toy.ferror(s, ... )
    print(sfmt(s,...))
end

function toy.task()
    local ret = {}
    local t = 0
    for session,co in pairs(session_id_coroutine) do
        ret[session] = debug.traceback(co)
        t = t + 1
    end
    ret.n = t
    return ret
end

return toy