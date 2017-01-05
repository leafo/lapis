[[
local config = require("lapis.config")
config({"development", "testing","production"}, {
  app_name = "My New Lapis App",
  port = 8080
})

config({"testing"}, {
  port = 8080
})

config({"production"}, {
  port = 80
})
]]