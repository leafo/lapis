local columnize
do
  local _obj_0 = require("lapis.cmd.util")
  columnize = _obj_0.columnize
end
local find_nginx
do
  local _obj_0 = require("lapis.cmd.nginx")
  find_nginx = _obj_0.find_nginx
end
local path = require("lapis.cmd.path")
local config = require("lapis.config")
local colors = require("ansicolors")
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
  mkdir = colors("%{bright}%{magenta}made directory%{reset}"),
  write_file = colors("%{bright}%{yellow}wrote%{reset}")
})
local write_file_safe
write_file_safe = function(file, content)
  if path.exists(file) then
    return 
  end
  return path.write_file(file, content)
end
local parse_flags
parse_flags = function(...)
  local input = {
    ...
  }
  local flags = { }
  local filtered
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #input do
      local _continue_0 = false
      repeat
        local arg = input[_index_0]
        do
          local flag = arg:match("^%-%-?(.+)$")
          if flag then
            local k, v = flag:match("(.-)=(.*)")
            if k then
              flags[k] = v
            else
              flags[flag] = true
            end
            _continue_0 = true
            break
          end
        end
        local _value_0 = arg
        _accum_0[_len_0] = _value_0
        _len_0 = _len_0 + 1
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    filtered = _accum_0
  end
  return flags, unpack(filtered)
end
local tasks
local get_task
get_task = function(name)
  for k, v in ipairs(tasks) do
    if v.name == name then
      return v
    end
  end
end
tasks = {
  default = "help",
  {
    name = "new",
    help = "create a new lapis project in the current directory",
    function(...)
      local flags = parse_flags(...)
      if path.exists("nginx.conf") then
        print(colors("%{bright}%{red}Aborting:%{reset} nginx.conf already exists"))
        return 
      end
      write_file_safe("nginx.conf", require("lapis.cmd.templates.config"))
      write_file_safe("mime.types", require("lapis.cmd.templates.mime_types"))
      write_file_safe("web.moon", require("lapis.cmd.templates.web"))
      if flags.git then
        write_file_safe(".gitignore", require("lapis.cmd.templates.gitignore")(flags))
      end
      if flags.tup then
        local tup_files = require("lapis.cmd.templates.tup")
        for fname, content in pairs(tup_files) do
          write_file_safe(fname, content)
        end
      end
    end
  },
  {
    name = "server",
    usage = "server [environment]",
    help = "build config and start server",
    function(environment)
      if environment == nil then
        environment = "development"
      end
      local nginx = find_nginx()
      if not (nginx) then
        print("Aborting, can not find an installation of OpenResty")
        return 
      end
      get_task("build")[1](environment)
      path.mkdir("logs")
      os.execute("touch logs/error.log")
      os.execute("touch logs/access.log")
      return os.execute("LAPIS_ENVIRONMENT='" .. tostring(environment) .. "' " .. nginx .. ' -p "$(pwd)" -c "nginx.conf.compiled"')
    end
  },
  {
    name = "build",
    usage = "build [environment]",
    help = "build the config",
    function(environment)
      if environment == nil then
        environment = "development"
      end
      local vars = config.get(environment)
      local compile_config
      do
        local _obj_0 = require("lapis.cmd.nginx")
        compile_config = _obj_0.compile_config
      end
      local compiled = compile_config(path.read_file("nginx.conf"), vars)
      return path.write_file("nginx.conf.compiled", compiled)
    end
  },
  {
    name = "help",
    help = "show this text",
    function()
      print("Lapis " .. tostring(require("lapis.version")))
      print("usage: lapis <action> [arguments]")
      do
        local nginx = find_nginx()
        if nginx then
          print("using nginx: " .. tostring(nginx))
        else
          print("can not find installation of OpenResty")
        end
      end
      print()
      print("Available actions:")
      print()
      print(columnize((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #tasks do
          local t = tasks[_index_0]
          _accum_0[_len_0] = {
            t.usage or t.name,
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
local execute
execute = function(args)
  local task_name = args[1] or tasks.default
  local task_args
  do
    local _accum_0 = { }
    local _len_0 = 1
    for i, a in ipairs(args) do
      if i > 1 then
        _accum_0[_len_0] = a
        _len_0 = _len_0 + 1
      end
    end
    task_args = _accum_0
  end
  do
    local task = get_task(task_name)
    if task then
      return assert(task[1], "action `" .. tostring(task_name) .. "' not implemented")(unpack(task_args))
    else
      print("Error: unknown command `" .. tostring(task_name) .. "'")
      return get_task("help")[1](unpack(task_args))
    end
  end
end
return {
  tasks = tasks,
  execute = execute
}
