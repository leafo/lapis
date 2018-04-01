local lapis = require("lapis")
local app = lapis.Application()

local capture_errors_json = require("lapis.application").capture_errors_json
local json_params = require("lapis.application").json_params

app:get("/", function()
  return "Welcome to Lapis " .. require("lapis.version")
end)

app:get("/world", function()
  return { json = { success = true } }
end)

app:get("/form", function(self)
  local csrf = require "lapis.csrf"

  return {
    json = {
      csrf_token = csrf.generate_token(self)
    }
  }
end)

app:post("/form", capture_errors_json(function(self)
  local csrf = require "lapis.csrf"
  csrf.assert_token(self)
  return {
    json = { success = true }
  }
end))

app:match("/dump-params", function(self)
  return {
    json = self.params
  }
end)

app:match("/dump-json-params", json_params(function(self)
  return {
    json = self.params
  }
end))

return app
