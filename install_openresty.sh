#!/bin/bash

# example:
# OPENRESTY=1.9.3.2 ./install_openresty
# will install it to $TRAVIS_BUILD_DIR/install/openresty

set -eufo pipefail

base_dir=$(pwd)
openresty_tar="ngx_openresty-${OPENRESTY}.tar.gz"
pcre_tar="pcre-8.33.tar.gz"

echo "$(tput setaf 2)Downloading openresty ${OPENRESTY}...$(tput sgr0)"
curl -O -L "http://openresty.org/download/$openresty_tar"
echo "$(tput setaf 2)Downloading pcre...$(tput sgr0)"
curl -O -L "http://downloads.sourceforge.net/sourceforge/pcre/$pcre_tar"

tar -xzf "$openresty_tar"
tar -xzf "$pcre_tar"

pcre_dir="$base_dir/$(find . -maxdepth 1 -type d | grep pcre-)"

install_dir="install/openresty"

echo "$(tput setaf 2)Building openresty...$(tput sgr0)"
(
	cd $(find . -maxdepth 1 -type d | grep ngx_openresty-)
	./configure --with-pcre=$pcre_dir --with-http_postgres_module
	make
	mkdir -p "$install_dir"
	make DESTDIR="$install_dir" install
)

echo "$(tput setaf 2)Done!$(tput sgr0)"
find "$install_dir"

