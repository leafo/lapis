local default_environment, columnize
do
  local _obj_0 = require("lapis.cmd.util")
  default_environment, columnize = _obj_0.default_environment, _obj_0.columnize
end
local find_nginx, start_nginx, write_config_for, get_pid
do
  local _obj_0 = require("lapis.cmd.nginx")
  find_nginx, start_nginx, write_config_for, get_pid = _obj_0.find_nginx, _obj_0.start_nginx, _obj_0.write_config_for, _obj_0.get_pid
end
local find_leda, start_leda
do
  local _obj_0 = require("lapis.cmd.leda")
  find_leda, start_leda = _obj_0.find_leda, _obj_0.start_leda
end
local path = require("lapis.cmd.path")
local config = require("lapis.config")
local colors = require("ansicolors")
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
local fail_with_message
fail_with_message = function(msg)
  print(colors("%{bright}%{red}Aborting:%{reset} " .. msg))
  return os.exit(1)
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
      local CONFIG_PATH, CONFIG_PATH_ETLUA
      do
        local _obj_0 = require("lapis.cmd.nginx")
        CONFIG_PATH, CONFIG_PATH_ETLUA = _obj_0.CONFIG_PATH, _obj_0.CONFIG_PATH_ETLUA
      end
      local flags = parse_flags(...)
      if path.exists(CONFIG_PATH) or path.exists(CONFIG_PATH_ETLUA) then
        fail_with_message("nginx.conf already exists")
      end
      if flags["etlua-config"] then
        write_file_safe(CONFIG_PATH_ETLUA, require("lapis.cmd.templates.config_etlua"))
      else
        write_file_safe(CONFIG_PATH, require("lapis.cmd.templates.config"))
      end
      write_file_safe("mime.types", require("lapis.cmd.templates.mime_types"))
      if flags.lua then
        write_file_safe("app.lua", require("lapis.cmd.templates.app_lua"))
      else
        write_file_safe("app.moon", require("lapis.cmd.templates.app"))
      end
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
        environment = default_environment()
      end
      local nginx = find_nginx()
      local leda = find_leda()
      if not (nginx or leda) then
        fail_with_message("can not find suitable server installation")
      end
      if nginx then
        write_config_for(environment)
        return start_nginx()
      else
        return start_leda(environment)
      end
    end
  },
  {
    name = "build",
    usage = "build [environment]",
    help = "build config, send HUP if server running",
    function(environment)
      if environment == nil then
        environment = default_environment()
      end
      write_config_for(environment)
      local send_hup
      send_hup = require("lapis.cmd.nginx").send_hup
      local pid = send_hup()
      if pid then
        return print(colors("%{green}HUP " .. tostring(pid)))
      end
    end
  },
  {
    name = "hup",
    hidden = true,
    help = "send HUP signal to running server",
    function()
      local send_hup
      send_hup = require("lapis.cmd.nginx").send_hup
      local pid = send_hup()
      if pid then
        return print(colors("%{green}HUP " .. tostring(pid)))
      else
        return fail_with_message("failed to find nginx process")
      end
    end
  },
  {
    name = "term",
    help = "sends TERM signal to shut down a running server",
    function()
      local send_term
      send_term = require("lapis.cmd.nginx").send_term
      local pid = send_term()
      if pid then
        return print(colors("%{green}TERM " .. tostring(pid)))
      else
        return fail_with_message("failed to find nginx process")
      end
    end
  },
  {
    name = "signal",
    hidden = true,
    help = "send arbitrary signal to running server",
    function(signal)
      assert(signal, "Missing signal")
      local send_signal
      send_signal = require("lapis.cmd.nginx").send_signal
      local pid = send_signal(signal)
      if pid then
        return print(colors("%{green}Sent " .. tostring(signal) .. " to " .. tostring(pid)))
      else
        return fail_with_message("failed to find nginx process")
      end
    end
  },
  {
    name = "exec",
    usage = "exec <lua-string>",
    help = "execute Lua on the server",
    function(code, environment)
      if environment == nil then
        environment = default_environment()
      end
      if not (code) then
        fail_with_message("missing lua-string: exec <lua-string>")
      end
      local attach_server
      attach_server = require("lapis.cmd.nginx").attach_server
      if not (get_pid()) then
        print(colors("%{green}Using temporary server..."))
      end
      local server = attach_server(environment)
      print(server:exec(code))
      return server:detach()
    end
  },
  {
    name = "migrate",
    usage = "migrate [environment]",
    help = "run migrations",
    function(environment)
      if environment == nil then
        environment = default_environment()
      end
      local attach_server
      attach_server = require("lapis.cmd.nginx").attach_server
      if not (get_pid()) then
        print(colors("%{green}Using temporary server..."))
      end
      local server = attach_server(environment)
      print(server:exec([[        local migrations = require("lapis.db.migrations")
        migrations.create_migrations_table()
        migrations.run_migrations(require("migrations"))
      ]]))
      return server:detach()
    end
  },
  {
    name = "generate",
    usage = "generate template [args...]",
    help = "generates a new file from template",
    function(template_name, ...)
      local tpl = require("lapis.cmd.templates." .. tostring(template_name))
      if not (type(tpl) == "table") then
        error("invalid template: " .. tostring(template_name))
      end
      local out = tpl.content(...)
      local fname = tpl.filename(...)
      return write_file_safe(fname, out)
    end
  },
  {
    name = "help",
    help = "show this text",
    function()
      print(colors("Lapis " .. tostring(require("lapis.version"))))
      print("usage: lapis <action> [arguments]")
      local nginx = find_nginx()
      local leda = find_leda()
      if nginx then
        print("using nginx: " .. tostring(nginx))
      elseif leda then
        print("using leda: " .. tostring(leda))
      else
        print("can not find suitable server installation")
      end
      print("default environment: " .. tostring(default_environment()))
      print()
      print("Available actions:")
      print()
      print(columnize((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #tasks do
          local t = tasks[_index_0]
          if not t.hidden then
            _accum_0[_len_0] = {
              t.usage or t.name,
              t.help
            }
            _len_0 = _len_0 + 1
          end
        end
        return _accum_0
      end)()))
      return print()
    end
  }
}
local format_error
format_error = function(msg)
  return colors("%{bright red}Error:%{reset} " .. tostring(msg))
end
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
  local task = get_task(task_name)
  if not (task) then
    print(format_error("unknown command `" .. tostring(task_name) .. "'"))
    get_task("help")[1](unpack(task_args))
    return 
  end
  local fn = assert(task[1], "action `" .. tostring(task_name) .. "' not implemented")
  return xpcall((function()
    return fn(unpack(task_args))
  end), function(err)
    local flags = parse_flags(unpack(task_args))
    if not (flags.trace) then
      err = err:match("^.-:.-:.(.*)$") or err
    end
    local msg = colors("%{bright red}Error:%{reset} " .. tostring(err))
    if flags.trace then
      print(debug.traceback(msg, 2))
    else
      print(msg)
      print(" * Run with --trace to see traceback")
      print(" * Report issues to https://github.com/leafo/lapis/issues")
    end
    return os.exit(1)
  end)
end
return {
  tasks = tasks,
  execute = execute
}
