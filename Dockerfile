FROM ghcr.io/leafo/lapis-archlinux:2026-04-24
MAINTAINER leaf corcoran <leafot@gmail.com>

WORKDIR /site/lapis

RUN luarocks --lua-version=5.1 install busted && \
	luarocks --lua-version=5.1 install lpeg && \
	luarocks --lua-version=5.1 install moonscript && \
	luarocks --lua-version=5.1 install luaposix && \
	luarocks --lua-version=5.1 install luasql-mysql MYSQL_INCDIR=/usr/include/mysql && \
	luarocks --lua-version=5.1 install http

ADD . .

ENTRYPOINT ./ci.sh
