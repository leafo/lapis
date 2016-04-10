local check_args
check_args = function(name, more)
  if not (name) then
    error("flow template takes arguments: name")
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
  return "flows/" .. tostring(name) .. ".moon"
end
local content
content = function(name)
  return [[import Flow from require "lapis.flow"

class ]] .. name .. [[ extends Flow
  ]]
end
local write
write = function(writer, name)
  local camelize
  camelize = require("lapis.util").camelize
  local tail_name = name:match("[^.]+$") or name
  local class_name = camelize(tail_name) .. "Flow"
  local path = writer:mod_to_path(name)
  return writer:write(filename(path), content(class_name))
end
return {
  check_args = check_args,
  write = write
}
