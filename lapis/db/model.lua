local config = require("lapis.config").get()
if config.postgres then
  return require("lapis.db.postgres.model")
elseif config.mysql then
  return require("lapis.db.mysql.model")
elseif config.sqlite then
  return require("lapis.db.sqlite.model")
else
  return error("Database type could not be determined from configuration (postgres, mysql, sqlite)")
end
