
local: build
	luarocks make --local lapis-dev-1.rockspec

global: build
	sudo luarocks make lapis-dev-1.rockspec

build::
	moonc lapis

watch:: build
	moonc -w lapis


