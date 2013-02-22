local columnize
do
  local _table_0 = require("lapis.cmd.util")
  columnize = _table_0.columnize
end
local path = require("lapis.cmd.path")
local log
log = function(...)
  return print("->", ...)
end
local find_nginx
do
  local nginx_bin = "nginx"
  local nginx_search_paths = {
    "/usr/local/openresty/nginx/sbin/",
    "/usr/sbin/",
    ""
  }
  local nginx_path
  find_nginx = function()
    if nginx_path then
      return nginx_path
    end
    local _list_0 = nginx_search_paths
    for _index_0 = 1, #_list_0 do
      local prefix = _list_0[_index_0]
      local cmd = tostring(prefix) .. tostring(nginx_bin) .. " -v 2>&1"
      local handle = io.popen(cmd)
      local out = handle:read()
      handle:close()
      if out:match("^nginx version: ngx_openresty/1.2.6.6") then
        nginx_path = tostring(prefix) .. tostring(nginx_bin)
        return nginx_path
      end
    end
  end
end
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
          local first = ...
          return log(verbs[name], first)
        end
      else
        return fn
      end
    end
  })
end
path = annotate(path, {
  mkdir = "made directory",
  write_file = "wrote"
})
local tasks
tasks = {
  default = "help",
  {
    name = "new",
    help = "create a new lapis project in the current directory",
    function()
      path.mkdir("logs")
      path.mkdir("conf")
      path.write_file("nginx.conf", require("lapis.cmd.templates.config"))
      return path.write_file("mime.types", require("lapis.cmd.templates.mime_types"))
    end
  },
  {
    name = "server",
    help = "start the development server"
  },
  {
    name = "help",
    help = "show this text",
    function()
      print("Lapis " .. tostring(require("lapis.version")))
      print("usage: lapis <action> [arguments]")
      print("using nginx: " .. tostring(find_nginx()))
      print()
      print("Available actions:")
      print()
      print(columnize((function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = tasks
        for _index_0 = 1, #_list_0 do
          local t = _list_0[_index_0]
          _accum_0[_len_0] = {
            t.name,
            t.help
          }
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)()))
      return print()
    end
  }
}
local get_task
get_task = function(name)
  for k, v in ipairs(tasks) do
    if v.name == name then
      return v
    end
  end
end
local execute
execute = function(args)
  local task_name = args[1] or tasks.default
  return get_task(task_name)[1](args)
end
return {
  tasks = tasks,
  execute = execute
}
