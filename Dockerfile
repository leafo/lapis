FROM ghcr.io/leafo/lapis-archlinux
MAINTAINER leaf corcoran <leafot@gmail.com>

WORKDIR /site/lapis

RUN luarocks --lua-version=5.1 install --local busted && \
	luarocks --lua-version=5.1 install --local lpeg && \
	luarocks --lua-version=5.1 install --local moonscript && \
	# TODO: https://github.com/luaposix/luaposix/issues/285#issuecomment-316583187 && \
	luarocks --lua-version=5.1 install --local https://luarocks.org/manifests/gvvaughan/luaposix-33.4.0-1.rockspec && \
	luarocks --lua-version=5.1 install --local luasql-mysql MYSQL_INCDIR=/usr/include/mysql && \
	luarocks --lua-version=5.1 install --local http

ADD . .

ENTRYPOINT ./ci.sh
