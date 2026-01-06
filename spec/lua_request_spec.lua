local lapis = require("lapis.application")
local simulate_request = require("lapis.spec.request").simulate_request

local app = lapis.Application()

app:match("/hello", function(self)
  return "welcome to my page"
end)

-- busted procedures below
describe("my application", function()
  it("should make a request", function()
    local status, body = simulate_request(app, "/hello")
    assert.same(200, status)
    assert.truthy(body:match("welcome"))
  end)
end)
