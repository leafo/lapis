#!/bin/bash
set -e
set -o pipefail
set -o xtrace

luarocks-5.1 install busted
luarocks-5.1 install lpeg 0.10.2
luarocks-5.1 install moonscript
luarocks-5.1 install luaposix
luarocks-5.1 install date
luarocks-5.1 install luasql-mysql MYSQL_INCDIR=/usr/include/mysql
luarocks-5.1 make

eval $(luarocks-5.1 path)

# setup busted
cat $(which busted) | sed 's/\/usr\/bin\/lua5\.1/\/usr\/bin\/luajit/' > busted
chmod +x busted

# start postgres
echo "fsync = off" >> /var/lib/postgres/data/postgresql.conf
echo "synchronous_commit = off" >> /var/lib/postgres/data/postgresql.conf
echo "full_page_writes = off" >> /var/lib/postgres/data/postgresql.conf
su postgres -c '/usr/bin/pg_ctl -s -D /var/lib/postgres/data start -w -t 120'

make build
make test_db

./busted -o utfTerminal
./busted -o utfTerminal spec_postgres/
./busted -o utfTerminal spec_openresty/
