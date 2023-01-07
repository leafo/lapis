local io = io
local shell_escape
shell_escape = function(str)
  return str:gsub("'", "'\\''")
end
local LAPIS_GENERATE_STDOUT, up, exists, normalize, basepath, filename, write_file, read_file, mkdir, join, exec, mod
LAPIS_GENERATE_STDOUT = os.getenv("LAPIS_GENERATE_STDOUT")
up = function(path)
  path = path:gsub("/$", "")
  path = path:gsub("[^/]*$", "")
  if path ~= "" then
    return path
  end
end
exists = function(path)
  local file = io.open(path)
  if file then
    return file:close() and true
  end
end
normalize = function(path)
  return (path:gsub("^%./", ""))
end
basepath = function(path)
  return (path:match("^(.*)/[^/]*$") or ".")
end
filename = function(path)
  return (path:match("([^/]*)$"))
end
write_file = function(path, content)
  assert(content, "trying to write file with no content")
  if LAPIS_GENERATE_STDOUT then
    return print(content)
  else
    do
      local _with_0 = assert(io.open(path, "w"))
      _with_0:write(content)
      _with_0:close()
      return _with_0
    end
  end
end
read_file = function(path)
  local file = io.open(path)
  if not (file) then
    error("file doesn't exist `" .. tostring(path) .. "'")
  end
  do
    local _with_0 = file:read("*a")
    file:close()
    return _with_0
  end
end
mkdir = function(path)
  if LAPIS_GENERATE_STDOUT then
    return 
  end
  return os.execute("mkdir -p '" .. tostring(shell_escape(path)) .. "'")
end
join = function(a, b)
  if a ~= "/" then
    a = a:match("^(.*)/$") or a
  end
  b = b:match("^/(.*)$") or b
  if a == "" then
    return b
  end
  if b == "" then
    return a
  end
  return a .. "/" .. b
end
exec = function(cmd, ...)
  local args
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local x = _list_0[_index_0]
      _accum_0[_len_0] = shell_escape(x)
      _len_0 = _len_0 + 1
    end
    args = _accum_0
  end
  args = table.concat(args, " ")
  local full_cmd = tostring(cmd) .. " " .. tostring(args)
  return os.execute(full_cmd)
end
mod = {
  up = up,
  exists = exists,
  normalize = normalize,
  basepath = basepath,
  filename = filename,
  write_file = write_file,
  mkdir = mkdir,
  join = join,
  read_file = read_file,
  shell_escape = shell_escape,
  exec = exec
}
do
  local log = print
  local annotate
  annotate = function(obj, verbs)
    return setmetatable({ }, {
      __newindex = function(self, name, value)
        obj[name] = value
      end,
      __index = function(self, name)
        local fn = obj[name]
        if not type(fn) == "function" then
          return fn
        end
        if verbs[name] then
          return function(...)
            log(verbs[name], (...))
            return fn(...)
          end
        else
          return fn
        end
      end
    })
  end
  mod.annotate = function()
    local colors = require("ansicolors")
    return annotate(mod, {
      mkdir = colors("%{bright}%{magenta}make directory%{reset}"),
      write_file = colors("%{bright}%{yellow}write%{reset}"),
      exec = colors("%{bright}%{red}exec%{reset}")
    })
  end
end
return mod
