config = require("lapis.config").get!
if config.postgres
  require "lapis.db.postgres.model"
elseif config.mysql
  require "lapis.db.mysql.model"
elseif config.sqlite
  require "lapis.db.sqlite.model"
else
  error "Databse type could not be determined from configuration (postgres, mysql, sqlite)"
