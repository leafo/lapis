local check_args
check_args = function(name, more)
  if not (name) then
    error("model template takes arguments: name")
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
  return "models/" .. tostring(name) .. ".moon"
end
local write
write = function(writer, name)
  local camelize
  camelize = require("lapis.util").camelize
  local class_name = camelize(name)
  return writer:write(filename(name), [[db = require "lapis.db"
import Model from require "lapis.db.model"

class ]] .. class_name .. [[ extends Model
]])
end
return {
  check_args = check_args,
  write = write
}
