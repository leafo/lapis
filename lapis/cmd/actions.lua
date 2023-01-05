local columnize, parse_flags, write_file_safe
do
  local _obj_0 = require("lapis.cmd.util")
  columnize, parse_flags, write_file_safe = _obj_0.columnize, _obj_0.parse_flags, _obj_0.write_file_safe
end
local colors = require("ansicolors")
local unpack = unpack or table.unpack
local COMMANDS = {
  {
    name = "new",
    help = "Create a new Lapis project in the current directory",
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:mutex(_with_0:flag("--cqueues", "Generate config for cqueues server"), _with_0:flag("--nginx", "Generate config for nginx server"))
        _with_0:mutex(_with_0:flag("--lua", "Generate app template file in Lua"), _with_0:flag("--moonscript --moon", "Generate app template file in MoonScript"))
        _with_0:flag("--etlua-config", "Use etlua for templmated configuration files (eg. nginx.conf)")
        _with_0:flag("--git", "Generate default .gitignore file")
        _with_0:flag("--tup", "Generate default Tupfile")
        return _with_0
      end
    end,
    function(self, args)
      local server_actions
      if args.cqueues then
        server_actions = require("lapis.cmd.cqueues.actions")
      else
        server_actions = require("lapis.cmd.nginx.actions")
      end
      server_actions.new(self, args)
      if args.lua then
        self:write_file_safe("app.lua", require("lapis.cmd.templates.app_lua"))
        self:write_file_safe("models.lua", require("lapis.cmd.templates.models_lua"))
      else
        self:write_file_safe("app.moon", require("lapis.cmd.templates.app"))
        self:write_file_safe("models.moon", require("lapis.cmd.templates.models"))
      end
      if args.git then
        self:write_file_safe(".gitignore", require("lapis.cmd.templates.gitignore")(args))
      end
      if args.tup then
        local tup_files = require("lapis.cmd.templates.tup")
        for fname, content in pairs(tup_files) do
          self:write_file_safe(fname, content)
        end
      end
    end
  },
  {
    name = "server",
    aliases = {
      "serve"
    },
    help = "Start the server from the current directory",
    argparse = function(command)
      return command:argument("environment"):args("?")
    end,
    function(self, args)
      local environment
      environment = args.environment
      return self:get_server_actions(environment).server(self, args, environment)
    end
  },
  {
    name = "build",
    help = "Rebuild configuration and send a reload signal to running server",
    context = {
      "nginx"
    },
    argparse = function(command)
      return command:argument("environment"):args("?")
    end,
    function(self, flags)
      local write_config_for
      write_config_for = require("lapis.cmd.nginx").write_config_for
      write_config_for(flags.environment)
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
    help = "Send HUP signal to running server",
    context = {
      "nginx"
    },
    function(self)
      local send_hup
      send_hup = require("lapis.cmd.nginx").send_hup
      local pid = send_hup()
      if pid then
        return print(colors("%{green}HUP " .. tostring(pid)))
      else
        return self:fail_with_message("failed to find nginx process")
      end
    end
  },
  {
    name = "term",
    help = "Sends TERM signal to shut down a running server",
    context = {
      "nginx"
    },
    function(self)
      local send_term
      send_term = require("lapis.cmd.nginx").send_term
      local pid = send_term()
      if pid then
        return print(colors("%{green}TERM " .. tostring(pid)))
      else
        return self:fail_with_message("failed to find nginx process")
      end
    end
  },
  {
    name = "signal",
    hidden = true,
    help = "Send arbitrary signal to running server",
    context = {
      "nginx"
    },
    argparse = function(command)
      return command:argument("signal", "Signal to send, eg. TERM, SIGHUP, etc.")
    end,
    function(self, args)
      local signal
      signal = args.signal
      local send_signal
      send_signal = require("lapis.cmd.nginx").send_signal
      local pid = send_signal(signal)
      if pid then
        return print(colors("%{green}Sent " .. tostring(signal) .. " to " .. tostring(pid)))
      else
        return self:fail_with_message("failed to find nginx process")
      end
    end
  },
  {
    name = "exec",
    aliases = {
      "execute"
    },
    help = "Execute Lua on the server",
    context = {
      "nginx"
    },
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:argument("code", "String code to execute. Set - to read code from stdin")
        _with_0:mutex(_with_0:flag("--lua", "Execute code as Lua"))
        return _with_0
      end
    end,
    function(self, flags)
      local attach_server, get_pid
      do
        local _obj_0 = require("lapis.cmd.nginx")
        attach_server, get_pid = _obj_0.attach_server, _obj_0.get_pid
      end
      if not (get_pid()) then
        print(colors("%{green}Using temporary server..."))
      end
      local server = attach_server(flags.environment)
      print(server:exec(flags.code))
      return server:detach()
    end
  },
  {
    name = "migrate",
    help = "Run any outstanding migrations",
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:argument("environment"):args("?")
        _with_0:option("--migrations-module", "Module to load for migrations"):argname("<module>"):default("migrations")
        _with_0:option("--transaction"):args("?"):choices({
          "global",
          "individual"
        }):action(function(args, name, val)
          args[name] = val[next(val)] or "global"
        end)
        return _with_0
      end
    end,
    function(self, args)
      local env = require("lapis.environment")
      env.push(args.environment, {
        show_queries = true
      })
      local migrations = require("lapis.db.migrations")
      migrations.run_migrations(require(args.migrations_module), nil, {
        transaction = args.transaction
      })
      return env.pop()
    end
  },
  {
    name = "generate",
    help = "Generates a new file in the current directory from template",
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:argument("template_name", "Which template to load (eg. model, flow)")
        _with_0:argument("template_args", "Template arguments"):args("*")
        _with_0:mutex(_with_0:flag("--moonscript --moon", "Prefer to generate MoonScript file when appropriate"), _with_0:flag("--lua", "Prefer to generate Lua file when appropriate"))
        return _with_0
      end
    end,
    function(self, args)
      local template_name, template_args
      template_name, template_args = args.template_name, args.template_args
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
        write = function(_, ...)
          return assert(self:write_file_safe(...))
        end,
        mod_to_path = function(self, mod)
          return mod:gsub("%.", "/")
        end
      }
      if tpl.check_args then
        tpl.check_args(unpack(template_args))
      end
      if not (type(tpl.write) == "function") then
        error("generator `#{module_name or }` is missing write function")
      end
      return tpl.write(writer, unpack(template_args))
    end
  },
  {
    name = "_",
    help = "Excute third-party command from module lapis.cmd.actions._",
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:handle_options(false)
        _with_0:argument("subcommand", "Which command module to load")
        _with_0:argument("args", "Arguments to command"):args("*")
        return _with_0
      end
    end,
    function(self)
      return error("This command is not implemented yet")
    end
  },
  {
    name = "systemd",
    help = "Generate systemd service file",
    test_available = function()
      return pcall(function()
        return require("lapis.cmd.actions.systemd")
      end)
    end,
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:argument("sub_command", "Sub command to execute"):choices({
          "service"
        })
        _with_0:argument("environment", "Environment to create service file for"):args("?")
        _with_0:flag("--install", "Installs the service file to the system, requires sudo permission")
        return _with_0
      end
    end,
    function(self)
      return error("not yet")
    end
  },
  {
    name = "annotate",
    help = "Annotate model files with schema information",
    test_available = function()
      return pcall(function()
        return require("lapis.cmd.actions.annotate")
      end)
    end,
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:argument("files", "Paths to model classes to annotate (eg. models/first.moon models/second.moon ...)"):args("+")
        return _with_0
      end
    end,
    function(self)
      return error("not yet")
    end
  }
}
local CommandRunner
do
  local _class_0
  local _base_0 = {
    default_action = "help",
    build_parser = function(self)
      local default_environment
      default_environment = require("lapis.environment").default_environment
      local find_nginx
      find_nginx = require("lapis.cmd.nginx").find_nginx
      colors = require("ansicolors")
      local argparse = require("argparse")
      local lua_http_status_string
      lua_http_status_string = function()
        local str
        pcall(function()
          str = colors("cqueues: %{bright}" .. tostring(require("cqueues").VERSION) .. "%{reset} lua-http: %{bright}" .. tostring(require("http.version").version) .. "%{reset}")
        end)
        return str
      end
      local parser = argparse("lapis", table.concat({
        "Control & create web applications written with Lapis",
        colors("Lapis: %{bright}" .. tostring(require("lapis.version"))),
        colors("Default environment: %{yellow}" .. tostring(default_environment())),
        (function()
          do
            local nginx = find_nginx()
            if nginx then
              return colors("OpenResty: %{bright}" .. tostring(nginx))
            else
              return "No OpenResty installation found"
            end
          end
        end)(),
        (function()
          do
            local status = lua_http_status_string()
            if status then
              return status
            else
              return "cqueues lua-http: not available"
            end
          end
        end)()
      }, "\n"))
      parser:command_target("command")
      parser:add_help_command()
      parser:option("--environment", "Override the default environment"):argname("<name>"):default(default_environment())
      parser:flag("--trace", "Show full error trace if lapis command fails")
      for _index_0 = 1, #COMMANDS do
        local _continue_0 = false
        repeat
          local command_spec = COMMANDS[_index_0]
          if command_spec.test_available then
            if not (command_spec.test_available()) then
              _continue_0 = true
              break
            end
          end
          local name = command_spec.name
          if command_spec.aliases then
            name = tostring(name) .. " " .. tostring(table.concat(command_spec.aliases, " "))
          end
          local help_string = command_spec.help
          if command_spec.context then
            help_string = tostring(help_string) .. " (server: " .. tostring(table.concat(command_spec.context, ", ")) .. ")"
          end
          local command = parser:command(name, help_string)
          if command_spec.hidden then
            command:hidden(true)
          end
          if type(command_spec.argparse) == "function" then
            command_spec.argparse(command)
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return parser
    end,
    format_error = function(self, msg)
      return colors("%{bright red}Error:%{reset} " .. tostring(msg))
    end,
    fail_with_message = function(self, msg)
      local running_in_test
      running_in_test = require("lapis.spec").running_in_test
      if running_in_test() then
        return error("Aborting: " .. tostring(msg))
      else
        print(colors("%{bright}%{red}Aborting:%{reset} " .. msg))
        return os.exit(1)
      end
    end,
    write_file_safe = function(self, file, content)
      colors = require("ansicolors")
      if self.path.exists(file) then
        return nil, "file already exists: " .. tostring(file)
      end
      do
        local prefix = file:match("^(.+)/[^/]+$")
        if prefix then
          if not (self.path.exists(prefix)) then
            self.path.mkdir(prefix)
          end
        end
      end
      self.path.write_file(file, content)
      return true
    end,
    parse_args = function(self, args)
      do
        local _tbl_0 = { }
        for i, a in pairs(args) do
          if type(i) == "number" and i > 0 then
            _tbl_0[i] = a
          end
        end
        args = _tbl_0
      end
      local parser = self:build_parser()
      if next(args) == nil then
        args = {
          self.default_action
        }
      end
      return parser:parse(args)
    end,
    execute = function(self, args)
      args = self:parse_args(args)
      local action = self:get_command(args.command)
      if action.context then
        assert(self:check_context(args.environment, action.context))
      end
      local fn = assert(action[1], "command `" .. tostring(args.command) .. "' not implemented")
      return fn(self, args)
    end,
    execute_safe = function(self, args)
      local trace = false
      for _index_0 = 1, #args do
        local v = args[_index_0]
        if v == "--trace" then
          trace = true
        end
      end
      local running_in_test
      running_in_test = require("lapis.spec").running_in_test
      if trace or running_in_test() then
        return self:execute(args)
      end
      return xpcall(function()
        return self:execute(args)
      end, function(err)
        err = err:match("^.-:.-:.(.*)$") or err
        local msg = colors("%{bright red}Error:%{reset} " .. tostring(err))
        print(msg)
        print(" * Run with --trace to see traceback")
        print(" * Report issues to https://github.com/leafo/lapis/issues")
        return os.exit(1)
      end)
    end,
    get_server_type = function(self, environment)
      local config = require("lapis.config").get(environment)
      return (assert(config.server, "failed to get server type from config (did you set `server`?)"))
    end,
    get_server_module = function(self, environment)
      return require("lapis.cmd." .. tostring(self:get_server_type(environment)))
    end,
    get_server_actions = function(self, environment)
      return require("lapis.cmd." .. tostring(self:get_server_type(environment)) .. ".actions")
    end,
    check_context = function(self, environment, contexts)
      local s = self:get_server_module()
      for _index_0 = 1, #contexts do
        local c = contexts[_index_0]
        if c == s.type then
          return true
        end
      end
      return nil, "Command not available for selected server (using " .. tostring(s.type) .. ", needs " .. tostring(table.concat(contexts, ", ")) .. ")"
    end,
    get_command = function(self, name)
      for k, v in ipairs(COMMANDS) do
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
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.path = require("lapis.cmd.path")
      self.path = self.path:annotate()
    end,
    __base = _base_0,
    __name = "CommandRunner"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  CommandRunner = _class_0
end
local actions = CommandRunner()
return {
  actions = actions,
  get_action = (function()
    local _base_0 = actions
    local _fn_0 = _base_0.get_command
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  execute = (function()
    local _base_0 = actions
    local _fn_0 = _base_0.execute_safe
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)()
}
