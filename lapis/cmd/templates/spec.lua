local content
content = function(name)
  return [[import
  load_test_server
  close_test_server
  request
  from require "lapis.spec.server"

import truncate_tables from require "lapis.spec.db"

describe "]] .. name .. [[", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  before_each ->

  it "should do something", ->
]]
end
local filename
filename = function(name)
  return "spec/" .. tostring(name) .. "_spec.moon"
end
return {
  content = content,
  filename = filename
}
