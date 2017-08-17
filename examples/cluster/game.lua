local toy = require "toy"
local timer = require "timer"
local utils = require "utils"
local cluster = require "cluster"

local sfmt = string.format 

local cmd = {}

function cmd.handshake(source, session, skey)
    print(sfmt("get req handshake %s from %s skey[%s]",session,source,skey))
    return session,skey
end

cluster.reg_msg_handler(cmd)

local cb = function (source, session, skey)
    print(sfmt("recv resp handshake %s from %s skey[%s]",session,source,skey))
end

local session = 0
local f
f = function ()
    local dest
    local skey
    if cluster.clustername() == "C1" then
        session = session + 1
        dest = "C2"
        skey = "asdfg"
    else
        session = session - 1
        dest = "C1"
        skey = "qwert"
    end
    print(sfmt("send req handshake %s to %s skey[%s]",session,dest,skey))
    cluster.call(cb, dest, "handshake", session, skey)
    timer.timeout(2*100, f)
end

f()