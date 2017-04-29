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


./busted -o utfTerminal
