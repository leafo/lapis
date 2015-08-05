config = require "lapis.config"

config("test", {
  mysql = {
    backend = "resty_mysql", -- luasql, resty_mysql
    database = "lapis_test",
    user = "root",
  }
})
