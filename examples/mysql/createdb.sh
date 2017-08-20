db=$3
mysql -u$1 -p$2 <<eof
drop database if exists ${db};
create database ${db};
eof
mysql -u$1 -p$2 ${db} < table.sql