local lapis = require("lapis")

local app = lapis.Application()
app:enable("etlua")

app:get("index", "/", function(self)
  -- renders views/index.etlua
  return { render = true }
end)

app:get("/user/:name", function(self)
  return "Welcome to " .. self.params.name .. "'s profile"
end)

app:get("/test.json", function(self)
  return { json = { status = "ok" } }
end)

return app

