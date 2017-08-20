CREATE TABLE IF NOT EXISTS  tbl_player
(
    rl_sName varchar(16) NOT NULL default '' COMMENT '列名',
    rl_sData MEDIUMBLOB NOT NULL COMMENT '数据',
    PRIMARY KEY (`rl_sName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='玩家数据';