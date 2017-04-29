FROM leafo/lapis-archlinux-itchio:latest
MAINTAINER leaf corcoran <leafot@gmail.com>

WORKDIR /site/lapis
ADD . .
ENTRYPOINT ./ci.sh
