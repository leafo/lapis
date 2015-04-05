config = require("lapis.config").get!
if config.postgres
  require "lapis.db.postgres.schema"
elseif config.mysql
  require "lapis.db.mysql.schema"
else
  error "You have to configure either postgres or mysql"
