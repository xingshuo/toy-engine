package.path , LUA_PATH = LUA_PATH
package.cpath , LUA_CPATH = LUA_CPATH

local toy = require "toy"
local gate = require "gate"
local timer = require "timer"

toy.start()

local port = toy.getenv("port")
port = tonumber(port)
assert(port)
gate.open({port = port})

local start_script = ...
assert(start_script)
local f = loadfile(start_script)
f()