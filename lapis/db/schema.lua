local config = require("lapis.config").get()
if config.postgres then
  return require("lapis.db.postgres.schema")
elseif config.mysql then
  return require("lapis.db.mysql.schema")
elseif config.sqlite then
  return require("lapis.db.sqlite.schema")
else
  return error("Databse type could not be determined from configuration (postgres, mysql, sqlite)")
end
