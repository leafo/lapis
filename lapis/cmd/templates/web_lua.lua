return [[local lapis = require "lapis"
local app = lapis.Application()

app:get("/", function()
  return "Welcome to Lapis " .. require("lapis.version")
end)

lapis.serve(app)
]]
