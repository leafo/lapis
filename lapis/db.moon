config = require("lapis.config").get!
if config.postgres
  require "lapis.db.postgres"
elseif config.mysql
  require "lapis.db.mysql"
elseif config.sqlite
  require "lapis.db.sqlite"
else
  error "Databse type could not be determined from configuration (postgres, mysql, sqlite)"
