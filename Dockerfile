FROM leafo/lapis-archlinux:latest
MAINTAINER leaf corcoran <leafot@gmail.com>

WORKDIR /site/lapis
ADD . .
ENTRYPOINT ./ci.sh
