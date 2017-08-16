package.path , LUA_PATH = LUA_PATH
package.cpath , LUA_CPATH = LUA_CPATH

local toy = require "toy"
local gate = require "gate"
local timer = require "timer"
local cluster = require "cluster"
local const = require "const"
local utils = require "utils"

toy.start()

local client_ports = toy.getenv("client_ports")
client_ports = utils.split_all(client_ports, ",")
for _,port in pairs(client_ports) do
    port = tonumber(port)
    assert(port)
    gate.open({port = port, opaque = const.SOCK_OPAQUE_CLIENT})
end

local cluscfg = toy.getenv("cluster")
if cluscfg then
    cluster.loadconfig(cluscfg)
    
    local cluster_port = toy.getenv("cluster_port")
    cluster_port = tonumber(cluster_port)
    assert(cluster_port)
    gate.open({port = cluster_port, opaque = const.SOCK_OPAQUE_CLUSTER})
end

local start_script = ...
assert(start_script)
local f = loadfile(start_script)
f()