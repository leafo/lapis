FROM ghcr.io/leafo/lapis-archlinux:2023-7-20
MAINTAINER leaf corcoran <leafot@gmail.com>

WORKDIR /site/lapis

RUN luarocks --lua-version=5.1 install busted && \
	luarocks --lua-version=5.1 install lpeg && \
	luarocks --lua-version=5.1 install moonscript && \
	# TODO: https://github.com/luaposix/luaposix/issues/285#issuecomment-316583187 && \
	luarocks --lua-version=5.1 install https://luarocks.org/manifests/gvvaughan/luaposix-33.4.0-1.rockspec && \
	luarocks --lua-version=5.1 install luasql-mysql MYSQL_INCDIR=/usr/include/mysql && \
	luarocks --lua-version=5.1 install http

ADD . .

ENTRYPOINT ./ci.sh
