local toy = require "toy"
local timer = require "timer"
local utils = require "utils"
local cluster = require "cluster"

local sfmt = string.format 

local cmd = {}

function cmd.handshake(source, session)
    print(sfmt("get req handshake %s from %s",session,source))
    return session
end

cluster.reg_msg_handler(cmd)

local cb = function (source, session)
    print(sfmt("recv resp handshake %s from %s",session,source))
end

local session = 0
local f
f = function ()
    local dest
    if cluster.clustername() == "C1" then
        session = session + 1
        dest = "C2"
    else
        session = session - 1
        dest = "C1"
    end
    print(sfmt("send req handshake %s to %s",session,dest))
    cluster.call(cb, dest, "handshake", session)
    timer.timeout(2*100, f)
end

f()