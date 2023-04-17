config = require("lapis.config").get!
if config.postgres
  require "lapis.db.postgres.schema"
elseif config.mysql
  require "lapis.db.mysql.schema"
elseif config.sqlite
  require "lapis.db.sqlite.schema"
else
  error "Database type could not be determined from configuration (postgres, mysql, sqlite)"
