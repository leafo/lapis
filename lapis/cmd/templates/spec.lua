local check_args
check_args = function(name)
  if not (name) then
    return error("spec template takes arguments: name")
  end
end
local content
content = function(name)
  return [[import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

describe "]] .. name .. [[", ->
  use_test_server!

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
  filename = filename,
  check_args = check_args
}
