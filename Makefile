
.PHONY: test local build lint test_db mysql_test_db clean test_lua51 test_lua52 test_lua53 clean_luarocks

test:
	busted spec
	busted spec_postgres
	busted spec_mysql
	busted spec_openresty

local: build
	luarocks --lua-version=5.1 make --force --local lapis-dev-1.rockspec

clean_luarocks:
	rm -rf luarocks51 luarocks52 luarocks53

luarocks5%:
	@echo "$$(tput setaf 3)Preparing Luarocks for 5.$*$$(tput sgr0)"
	luarocks --lua-version=5.$* --tree=luarocks5$* install busted
	luarocks --lua-version=5.$* --tree=luarocks5$* install moonscript
	luarocks --lua-version=5.$* --tree=luarocks5$* install https://raw.githubusercontent.com/leafo/lua-cjson/master/lua-cjson-dev-1.rockspec

test_lua51: luarocks51 build
	luarocks --lua-version=5.1 --tree=luarocks51 make lapis-dev-1.rockspec
	LUA_PATH="$$(luarocks --lua-version=5.1 path --lr-path);;" LUA_CPATH="$$(luarocks --lua-version=5.1 path --lr-cpath);;" luarocks51/bin/busted spec

test_lua52: luarocks52 build
	luarocks --lua-version=5.2 --tree=luarocks52 make lapis-dev-1.rockspec
	LUA_PATH="$$(luarocks --lua-version=5.2 path --lr-path);;" LUA_CPATH="$$(luarocks --lua-version=5.2 path --lr-cpath);;" luarocks52/bin/busted spec

test_lua53: luarocks53 build
	luarocks --lua-version=5.3 --tree=luarocks53 make lapis-dev-1.rockspec
	LUA_PATH="$$(luarocks --lua-version=5.3 path --lr-path);;" LUA_CPATH="$$(luarocks --lua-version=5.3 path --lr-cpath);;" luarocks53/bin/busted spec

build:
	moonc lapis
	moonc spec_openresty/s2
	moonc spec_mysql/models.moon

lint:
	moonc lint_config.moon
	moonc -l $$(find lapis | grep moon$$)

test_db:
	-dropdb -U postgres lapis_test
	createdb -U postgres lapis_test

mysql_test_db:
	# echo 'ALTER USER root@localhost IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD("")' | sudo mysql -u root
	echo 'drop database if exists lapis_test' | mysql -u root
	echo 'create database lapis_test' | mysql -u root

clean:
	rm $$(find lapis/ | grep \.lua$$)
