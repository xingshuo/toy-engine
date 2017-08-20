local toy = require "toy"
local timer = require "timer"
local mysqldriver = require "mysqldriver"
local utils = require "utils"
local cfg = require "sqlcfg"

function start( ... )
    os.execute(string.format("cd examples/mysql && sh createdb.sh %s %s %s",cfg.user,cfg.pwd,cfg.db))
    local function on_connect(db)
        db:query("set charset utf8")
    end
    local db_proxy = mysqldriver.connect({
        host="127.0.0.1",
        port=3306,
        db=cfg.db,
        user=cfg.user,
        pwd=cfg.pwd,
        max_packet_size = 1024 * 1024,
        on_connect = on_connect,
    })
    if not db_proxy then
        print("failed to connect",utils.table_str(cfg))
        return
    end
    print("testmysql success to connect to mysql server")

    db_proxy:query("insert into tbl_player (rl_sName,rl_sData) values (\'Bob\',\'aa\'),(\'Tomy\',\'bb\')", function (status, res, sql)
        print ( sql, utils.table_str( res ) )
    end)
    
    db_proxy:query("select * from tbl_player", function (status, res, sql)
        print ( sql, utils.table_str( res ) )
    end)

    db_proxy:query("delete from tbl_player where rl_sName=\'Tomy\'", function (status, res, sql)
        print ( sql, utils.table_str( res ) )
    end)

    db_proxy:query("select * from tbl_player", function (status, res, sql)
        print ( sql, utils.table_str( res ) )
    end)

    db_proxy:disconnect()
end

timer.timeout(0, start)