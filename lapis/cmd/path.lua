local io = io
local shell_escape
shell_escape = function(str)
  return str:gsub("'", "''")
end
local up, exists, normalize, basepath, filename, write_file, read_file, mkdir, copy, join, exec, mod
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
  do
    local _with_0 = io.open(path, "w")
    _with_0:write(content)
    _with_0:close()
    return _with_0
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
  return os.execute("mkdir -p '" .. tostring(shell_escape(path)) .. "'")
end
copy = function(src, dest)
  return os.execute("cp '" .. tostring(shell_escape(src)) .. "' '" .. tostring(shell_escape(dest)) .. "'")
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
  copy = copy,
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
            fn(...)
            return log(verbs[name], (...))
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
      mkdir = colors("%{bright}%{magenta}made directory%{reset}"),
      write_file = colors("%{bright}%{yellow}wrote%{reset}"),
      exec = colors("%{bright}%{red}exec%{reset}")
    })
  end
end
return mod
