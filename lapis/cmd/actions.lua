local columnize
do
  local _table_0 = require("lapis.cmd.util")
  columnize = _table_0.columnize
end
local find_nginx
do
  local _table_0 = require("lapis.cmd.nginx")
  find_nginx = _table_0.find_nginx
end
local path = require("lapis.cmd.path")
local log
log = function(...)
  return print("->", ...)
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
      if path.exists("nginx.conf") then
        print("Aborting, nginx.conf already exists")
        return 
      end
      path.mkdir("logs")
      path.mkdir("conf")
      path.write_file("nginx.conf", require("lapis.cmd.templates.config"))
      return path.write_file("mime.types", require("lapis.cmd.templates.mime_types"))
    end
  },
  {
    name = "server",
    help = "start the development server",
    function()
      local compile_config
      do
        local _table_0 = require("lapis.cmd.nginx")
        compile_config = _table_0.compile_config
      end
      local compiled = compile_config(path.read_file("nginx.conf"), {
        port = "8080",
        num_workers = "1"
      })
      path.write_file("nginx.conf.compiled", compiled)
      return os.execute(find_nginx() .. ' -p "$(pwd)" -c "nginx.conf.compiled"')
    end
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
  do
    local task = get_task(task_name)
    if task then
      return assert(task[1], "action `" .. tostring(task_name) .. "' not implemented")(args)
    else
      print("Error: unknown command `" .. tostring(task_name) .. "'")
      return get_task("help")[1](args)
    end
  end
end
return {
  tasks = tasks,
  execute = execute
}
