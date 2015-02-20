
test::
	busted

local: build
	luarocks make --local lapis-dev-1.rockspec

global: build
	sudo luarocks make lapis-dev-1.rockspec

build::
	moonc lapis

watch:: build
	moonc -w lapis

lint:
	moonc lint_config.moon
	moonc -l $$(find lapis | grep moon$$)


test_db:
	-dropdb -U postgres lapis_test
	createdb -U postgres lapis_test

clean::
	rm $$(find lapis/ | grep \.lua$$)
