#!/bin/bash
set -e
set -o pipefail
set -o xtrace

luarocks install busted
luarocks install lpeg 0.10.2
luarocks install moonscript
luarocks install luaposix
luarocks install date
luarocks install luasql-mysql MYSQL_INCDIR=/usr/include/mysql
luarocks make


./busted -o utfTerminal
