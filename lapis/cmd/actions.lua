local default_environment, columnize, parse_flags
do
  local _obj_0 = require("lapis.cmd.util")
  default_environment, columnize, parse_flags = _obj_0.default_environment, _obj_0.columnize, _obj_0.parse_flags
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
local colors = require("ansicolors")
path = path:annotate()
local set_path
set_path = function(p)
  path = p
end
local write_file_safe
write_file_safe = function(file, content)
  if path.exists(file) then
    return nil, "file already exists: " .. tostring(file)
  end
  do
    local prefix = file:match("^(.+)/[^/]+$")
    if prefix then
      if not (path.exists(prefix)) then
        path.mkdir(prefix)
      end
    end
  end
  path.write_file(file, content)
  return true
end
local fail_with_message
fail_with_message = function(msg)
  print(colors("%{bright}%{red}Aborting:%{reset} " .. msg))
  return os.exit(1)
end
local actions
local get_action
get_action = function(name)
  for k, v in ipairs(actions) do
    if v.name == name then
      return v
    end
  end
  local action
  pcall(function()
    action = require("lapis.cmd.actions." .. tostring(name))
  end)
  return action
end
actions = {
  default = "help",
  {
    name = "new",
    help = "create a new lapis project in the current directory",
    function(flags)
      local config_path, config_path_etlua
      do
        local _obj_0 = require("lapis.cmd.nginx").nginx_runner
        config_path, config_path_etlua = _obj_0.config_path, _obj_0.config_path_etlua
      end
      if path.exists(config_path) or path.exists(config_path_etlua) then
        fail_with_message("nginx.conf already exists")
      end
      if flags["etlua-config"] then
        write_file_safe(config_path_etlua, require("lapis.cmd.templates.config_etlua"))
      else
        write_file_safe(config_path, require("lapis.cmd.templates.config"))
      end
      write_file_safe("mime.types", require("lapis.cmd.templates.mime_types"))
      if flags.lua then
        write_file_safe("app.lua", require("lapis.cmd.templates.app_lua"))
        write_file_safe("models.lua", require("lapis.cmd.templates.models_lua"))
      else
        write_file_safe("app.moon", require("lapis.cmd.templates.app"))
        write_file_safe("models.moon", require("lapis.cmd.templates.models"))
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
    function(flags, environment)
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
    function(flags, environment)
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
    function(flags, signal)
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
    function(flags, code, environment)
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
    function(flags, environment)
      if environment == nil then
        environment = default_environment()
      end
      local env = require("lapis.environment")
      env.push(environment, {
        show_queries = true
      })
      local migrations = require("lapis.db.migrations")
      migrations.run_migrations(require("migrations"))
      return env.pop()
    end
  },
  {
    name = "generate",
    usage = "generate <template> [args...]",
    help = "generates a new file from template",
    function(flags, template_name, ...)
      local tpl, module_name
      pcall(function()
        module_name = "generators." .. tostring(template_name)
        tpl = require(module_name)
      end)
      if not (tpl) then
        tpl = require("lapis.cmd.templates." .. tostring(template_name))
      end
      if not (type(tpl) == "table") then
        error("invalid generator `" .. tostring(module_name or template_name) .. "`, module must be table")
      end
      local writer = {
        write = function(self, ...)
          return assert(write_file_safe(...))
        end,
        mod_to_path = function(self, mod)
          return mod:gsub("%.", "/")
        end
      }
      if tpl.check_args then
        tpl.check_args(...)
      end
      if not (type(tpl.write) == "function") then
        error("generator `" .. tostring(module_name or template_name) .. "` is missing write function")
      end
      return tpl.write(writer, ...)
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
        for _index_0 = 1, #actions do
          local t = actions[_index_0]
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
  do
    local _tbl_0 = { }
    for i, a in pairs(args) do
      if type(i) == "number" and i > 0 then
        _tbl_0[i] = a
      end
    end
    args = _tbl_0
  end
  local flags, plain_args = parse_flags(args)
  local action_name = plain_args[1] or actions.default
  local action = get_action(action_name)
  local rest
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 2, #plain_args do
      local arg = plain_args[_index_0]
      _accum_0[_len_0] = arg
      _len_0 = _len_0 + 1
    end
    rest = _accum_0
  end
  if not (action) then
    print(format_error("unknown command `" .. tostring(action_name) .. "'"))
    get_action("help")[1](unpack(rest))
    return 
  end
  local fn = assert(action[1], "action `" .. tostring(action_name) .. "' not implemented")
  return xpcall((function()
    return fn(flags, unpack(rest))
  end), function(err)
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
  actions = actions,
  execute = execute,
  get_action = get_action,
  parse_flags = parse_flags,
  set_path = set_path
}
