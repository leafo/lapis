config = require("lapis.config").get!
if config.postgres
  require "lapis.db.postgres.model"
elseif config.mysql
  require "lapis.db.mysql.model"
else
  error "You have to configure either postgres or mysql"
