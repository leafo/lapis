
local lua = require "lapis.lua"
local lapis = require "lapis.init"

local app = lua.class({
  ["/"] = function(self)
    return self:html(function()
      a({ href = self:url_for("user", { name = "leafo" }) }, "Go to profile")
    end)
  end,

  [{user = "/user/:name"}] = function(self)
    return self:html(function()
      h1(self.params.name)
      p("Welcome to " .. self.params.name .. "'s profile")
    end)
  end,

  ["/test.json"] = function(self)
    return {
      json = { status = "ok" }
    }
  end,

}, lapis.Application)

lapis.serve(app)
