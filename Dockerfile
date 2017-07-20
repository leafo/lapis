FROM leafo/lapis-archlinux:latest
MAINTAINER leaf corcoran <leafot@gmail.com>

WORKDIR /site/lapis

RUN luarocks-5.1 install busted && \
	luarocks-5.1 install lpeg 0.10.2 && \
	luarocks-5.1 install moonscript && \
	# TODO: https://github.com/luaposix/luaposix/issues/285#issuecomment-316583187 && \
	luarocks-5.1 install https://luarocks.org/manifests/gvvaughan/luaposix-33.4.0-1.rockspec && \
	luarocks-5.1 install luasql-mysql MYSQL_INCDIR=/usr/include/mysql

ADD . .

RUN luarocks-5.1 make

ENTRYPOINT ./ci.sh
