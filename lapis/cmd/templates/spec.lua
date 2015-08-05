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
local spec_types = {
  models = function(name)
    return [[import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

describe "]] .. name .. [[", ->
  use_test_env!

  before_each ->

  it "should ...", ->
]]
  end,
  applications = function(name)
    return [[import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

describe "]] .. name .. [[", ->
  use_test_server!

  before_each ->

  it "should ...", ->
]]
  end
}
spec_types.helpers = spec_types.models
local write
write = function(writer, name)
  local path = writer:mod_to_path(name)
  local prefix = name:match("^(.+)%.")
  return writer:write(filename(path), (spec_types[prefix] or spec_types.applications)(name))
end
return {
  check_args = check_args,
  write = write
}
