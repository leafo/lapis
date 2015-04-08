package = "lapis"
version = "dev-1"

source = {
	url = "git://github.com/leafo/lapis.git"
}

description = {
	summary = "A web framework for MoonScript & Lua",
	homepage = "http://leafo.net/lapis",
	maintainer = "Leaf Corcoran <leafot@gmail.com>",
	license = "MIT"
}

dependencies = {
	"lua ~> 5.1",

	"ansicolors",
	"etlua",
	"loadkit",
	"lpeg",
	"lua-cjson",
	"luacrypto",
	"luafilesystem",
	"luasocket",
	"mimetypes",
	"pgmoon",
}

build = {
	type = "builtin",
	modules = {
		["lapis"] = "lapis/init.lua",
		["lapis.application"] = "lapis/application.lua",
		["lapis.cache"] = "lapis/cache.lua",
		["lapis.cmd.actions"] = "lapis/cmd/actions.lua",
		["lapis.cmd.leda"] = "lapis/cmd/leda.lua",
		["lapis.cmd.nginx"] = "lapis/cmd/nginx.lua",
		["lapis.cmd.path"] = "lapis/cmd/path.lua",
		["lapis.cmd.templates.app"] = "lapis/cmd/templates/app.lua",
		["lapis.cmd.templates.app_lua"] = "lapis/cmd/templates/app_lua.lua",
		["lapis.cmd.templates.config"] = "lapis/cmd/templates/config.lua",
		["lapis.cmd.templates.config_etlua"] = "lapis/cmd/templates/config_etlua.lua",
		["lapis.cmd.templates.gitignore"] = "lapis/cmd/templates/gitignore.lua",
		["lapis.cmd.templates.mime_types"] = "lapis/cmd/templates/mime_types.lua",
		["lapis.cmd.templates.model"] = "lapis/cmd/templates/model.lua",
		["lapis.cmd.templates.spec"] = "lapis/cmd/templates/spec.lua",
		["lapis.cmd.templates.tup"] = "lapis/cmd/templates/tup.lua",
		["lapis.cmd.util"] = "lapis/cmd/util.lua",
		["lapis.config"] = "lapis/config.lua",
		["lapis.csrf"] = "lapis/csrf.lua",
		["lapis.db"] = "lapis/db.lua",
		["lapis.db.base"] = "lapis/db/base.lua",
		["lapis.db.migrations"] = "lapis/db/migrations.lua",
		["lapis.db.model"] = "lapis/db/model.lua",
		["lapis.db.mysql"] = "lapis/db/mysql.lua",
		["lapis.db.mysql.schema"] = "lapis/db/mysql/schema.lua",
		["lapis.db.pagination"] = "lapis/db/pagination.lua",
		["lapis.db.postgres"] = "lapis/db/postgres.lua",
		["lapis.db.postgres.schema"] = "lapis/db/postgres/schema.lua",
		["lapis.db.schema"] = "lapis/db/schema.lua",
		["lapis.environment"] = "lapis/environment.lua",
		["lapis.etlua"] = "lapis/etlua.lua",
		["lapis.features.etlua"] = "lapis/features/etlua.lua",
		["lapis.flow"] = "lapis/flow.lua",
		["lapis.html"] = "lapis/html.lua",
		["lapis.http"] = "lapis/http.lua",
		["lapis.leda"] = "lapis/leda.lua",
		["lapis.leda.files"] = "lapis/leda/files.lua",
		["lapis.logging"] = "lapis/logging.lua",
		["lapis.lua"] = "lapis/lua.lua",
		["lapis.nginx"] = "lapis/nginx.lua",
		["lapis.nginx.context"] = "lapis/nginx/context.lua",
		["lapis.nginx.http"] = "lapis/nginx/http.lua",
		["lapis.nginx.postgres"] = "lapis/nginx/postgres.lua",
		["lapis.router"] = "lapis/router.lua",
		["lapis.server"] = "lapis/server.lua",
		["lapis.session"] = "lapis/session.lua",
		["lapis.spec"] = "lapis/spec.lua",
		["lapis.spec.db"] = "lapis/spec/db.lua",
		["lapis.spec.request"] = "lapis/spec/request.lua",
		["lapis.spec.server"] = "lapis/spec/server.lua",
		["lapis.spec.shared"] = "lapis/spec/shared.lua",
		["lapis.spec.stack"] = "lapis/spec/stack.lua",
		["lapis.util"] = "lapis/util.lua",
		["lapis.util.encoding"] = "lapis/util/encoding.lua",
		["lapis.util.functions"] = "lapis/util/functions.lua",
		["lapis.validate"] = "lapis/validate.lua",
		["lapis.version"] = "lapis/version.lua",
		["lapis.views.error"] = "lapis/views/error.lua",
		["lapis.views.layout"] = "lapis/views/layout.lua",
	},
	install = {
		bin = { "bin/lapis" }
	},
}

