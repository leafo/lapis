config = require("lapis.config").get!
if config.postgres
  require "lapis.db.postgres"
elseif config.mysql
  require "lapis.db.mysql"
else
  error "You have to configure either postgres or mysql"
