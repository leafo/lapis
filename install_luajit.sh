#!/bin/sh

base_dir=$(pwd)

luajit_tar="LuaJIT-2.0.3.tar.gz"

echo "$(tput setaf 2)Downloading luajit...$(tput sgr0)"
curl -O -L "http://commondatastorage.googleapis.com/leafo/$luajit_tar"

tar -xzf $luajit_tar

echo "$(tput setaf 2)Building luajit...$(tput sgr0)"
(
	cd $(ls -d LuaJIT*/ | head -n 1)
	make
	cp src/luajit ../
)
