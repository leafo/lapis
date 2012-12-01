package = "lapis"
version = "dev-1"

source = {
	url = "git://github.com/leafo/lapis.git"
}

description = {
	summary = "A web framework for MoonScript & Lua",
	homepage = "http://leafo.net",
	maintainer = "Leaf Corcoran <leafot@gmail.com>",
	license = "MIT"
}

dependencies = {
	"lua >= 5.1",
	"ansicolors",
	"lpeg",
	"luasocket",
	-- -- sessions
	-- "cjson",
	-- "luacrypto",
}

build = {
	type = "builtin",
	modules = {
		["lapis"] = "lapis/init.lua",
		["lapis.application"] = "lapis/application.lua",
		["lapis.db"] = "lapis/db.lua",
		["lapis.db.model"] = "lapis/db/model.lua",
		["lapis.html"] = "lapis/html.lua",
		["lapis.logging"] = "lapis/logging.lua",
		["lapis.nginx"] = "lapis/nginx.lua",
		["lapis.nginx.http"] = "lapis/nginx/http.lua",
		["lapis.nginx.postgres"] = "lapis/nginx/postgres.lua",
		["lapis.router"] = "lapis/router.lua",
		["lapis.server"] = "lapis/server.lua",
		["lapis.session"] = "lapis/session.lua",
		["lapis.util"] = "lapis/util.lua",
		["lapis.util.path"] = "lapis/util/path.lua",
		["lapis.version"] = "lapis/version.lua",
		["lapis.views.error"] = "lapis/views/error.lua",
		["lapis.views.layout"] = "lapis/views/layout.lua",
		["lapis.xavante"] = "lapis/xavante.lua",
	},
}

