local mysql = require "mysql"
local const = require "const"
local toy = require "toy"

local errcode = const.ERRCODE

local db_proxy = {}
db_proxy.__index = db_proxy

function db_proxy:new( db )
    local o = {}
    setmetatable(o, self)
    o.db = db
    return o
end

function db_proxy:query_one(sql, cb)
    local res = self.db:query(sql)
    if res.badresult then
        cb(errcode.ERR, res, sql)
    else
        cb(errcode.OK, res[1], sql)
    end
end

function db_proxy:query(sql, cb)
    local res = self.db:query(sql)
    if res.badresult then
        cb(errcode.ERR, res, sql)
    else
        cb(errcode.OK, res, sql)
    end
end

function db_proxy:disconnect()
    self.db:disconnect()
    self.db = nil
end

local M = {}

function M.connect( opts )
    local db=mysql.connect({
        host= opts.host or "127.0.0.1",
        port= opts.port or 3306,
        database = assert(opts.db),
        user = opts.user or "root",
        password= opts.pwd or "123456",
        max_packet_size = opts.max_packet_size or 1024 * 1024,
        on_connect = opts.on_connect,
    })
    if not db then
        toy.error("failed to connect")
        return
    end
    return db_proxy:new( db )
end

return M