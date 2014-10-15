local lapis = require("lapis.application")
local mock_request = require("lapis.spec.request").mock_request

local app = lapis.Application()

app:match("/hello", function(self)
  return "welcome to my page"
end)

-- busted procedures below
describe("my application", function()
  it("should make a request", function()
    local status, body = mock_request(app, "/hello")
    assert.same(200, status)
    assert.truthy(body:match("welcome"))
  end)
end)
