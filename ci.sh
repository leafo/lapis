#!/bin/bash
set -e
set -o pipefail
set -o xtrace

eval $(luarocks --lua-version=5.1 path)
luarocks --lua-version=5.1 make lapis-dev-1.rockspec
luarocks --lua-version=5.1 install tableshape
luarocks --lua-version=5.1 install lsqlite3

# add openresty
export LUA_PATH="$LUA_PATH;/usr/local/openresty/lualib/?.lua"

# setup busted to run with luajit provided by openresty
cat $(which busted) | sed 's/\/usr\/bin\/lua5\.1/\/usr\/local\/openresty\/luajit\/bin\/luajit/' > busted
chmod +x busted

# start postgres
echo "fsync = off" >> /var/lib/postgres/data/postgresql.conf
echo "synchronous_commit = off" >> /var/lib/postgres/data/postgresql.conf
echo "full_page_writes = off" >> /var/lib/postgres/data/postgresql.conf
su postgres -c '/usr/bin/pg_ctl -s -D /var/lib/postgres/data start -w -t 120'

# start mysql
mkdir -p /run/mysqld
/usr/bin/mysqld --user=root --basedir=/usr --datadir=/var/lib/mysql &

make build
make test_db

# note we do this after build to give mysql time to fully start
echo 'ALTER USER root@localhost IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD("")' | mysql -u root
make mysql_test_db

echo 'user root;' >> spec_openresty/s2/nginx.conf

./busted -o utfTerminal
./busted -o utfTerminal spec_postgres/
./busted -o utfTerminal spec_mysql/
./busted -o utfTerminal spec_openresty/
./busted -o utfTerminal spec_cqueues/
