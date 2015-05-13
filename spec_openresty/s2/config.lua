config = require "lapis.config"

config("test", {
  mysql = {
    backend = "resty_mysql", -- luasql, resty_mysql
    host = "localhost",
    -- port: ""
    database = "lapis_test",
    user = "root",
  }
})
