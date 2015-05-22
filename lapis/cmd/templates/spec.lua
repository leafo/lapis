local check_args
check_args = function(name, more)
  if not (name) then
    error("spec template takes arguments: name")
  end
  if name:match("%u") then
    error("name should be underscore form, all lowercase")
  end
  if more then
    return error("got a second argument to generator, did you mean to pass a string?")
  end
end
local filename
filename = function(name)
  return "spec/" .. tostring(name) .. "_spec.moon"
end
local write
write = function(writer, name)
  return writer:write(filename(name), [[import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

describe "]] .. name .. [[", ->
  use_test_server!

  before_each ->

  it "should do something", ->
]])
end
return {
  check_args = check_args,
  write = write
}
