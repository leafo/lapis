local parse_flags
parse_flags = require("lapis.cmd.util").parse_flags
local colors = require("ansicolors")
local unpack = unpack or table.unpack
local default_language
default_language = function()
  do
    local f = io.open("config.moon")
    if f then
      f:close()
      return "moonscript"
    else
      return "lua"
    end
  end
end
local add_environment_argument
add_environment_argument = function(command, summary)
  do
    local _with_0 = command:argument("environment", summary)
    _with_0:args("?")
    _with_0:target("_environment")
    _with_0:action(function(args, name, val)
      if val then
        if args.environment then
          error("You tried to set the environment twice. Use either --environment or the environment argument, not both")
        end
        args.environment = val
      end
    end)
    return _with_0
  end
end
local COMMANDS = {
  {
    name = "new",
    help = "Create a new Lapis project in the current directory",
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:mutex(_with_0:flag("--nginx", "Generate config for nginx server (default)"), _with_0:flag("--cqueues", "Generate config for cqueues server"))
        _with_0:mutex(_with_0:flag("--lua", "Generate app template file in Lua (defaul)"), _with_0:flag("--moonscript --moon", "Generate app template file in MoonScript"))
        _with_0:flag("--etlua-config", "Use etlua for templated configuration files (eg. nginx.conf)")
        _with_0:flag("--git", "Generate default .gitignore file")
        _with_0:flag("--tup", "Generate default Tupfile")
        _with_0:flag("--force", "Bypass errors when detecting functional server environment")
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
      local language
      if args.lua then
        language = "lua"
      elseif args.moonscript then
        language = "moonscript"
      else
        language = default_language()
      end
      local _exp_0 = language
      if "lua" == _exp_0 then
        self:write_file_safe("app.lua", require("lapis.cmd.templates.app_lua"))
        self:write_file_safe("models.lua", require("lapis.cmd.templates.models_lua"))
      elseif "moonscript" == _exp_0 then
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
      return add_environment_argument(command)
    end,
    function(self, args)
      return self:get_server_actions(args.environment).server(self, args)
    end
  },
  {
    name = "build",
    help = "Rebuild configuration and send a reload signal to running server",
    context = {
      "nginx"
    },
    argparse = function(command)
      return add_environment_argument(command)
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
      return command:argument("signal", "Signal to send, eg. TERM, HUP, etc.")
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
      add_environment_argument(command)
      do
        local _with_0 = command
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
      print(colors("%{bright yellow}Running migrations for environment:%{reset} " .. tostring(args.environment)))
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
        _with_0:handle_options(false)
        _with_0:argument("template_name", "Which template to load (eg. model, flow, spec)")
        _with_0:argument("template_args", "Template arguments"):argname("<args>"):args("*")
        return _with_0
      end
    end,
    function(self, args)
      local template_name
      template_name = args.template_name
      local tpl, module_name
      if template_name == "--help" or template_name == "-h" then
        return self:execute({
          "help",
          "generate"
        })
      end
      pcall(function()
        module_name = "generators." .. tostring(template_name)
        tpl = require(module_name)
      end)
      if not (tpl) then
        tpl = require("lapis.cmd.templates." .. tostring(template_name))
      end
      if not (type(tpl) == "table") then
        error("invalid generator `" .. tostring(module_name or template_name) .. "`: module must be table")
      end
      if not (type(tpl.write) == "function") then
        error("invalid generator `" .. tostring(module_name or template_name) .. "`: is missing write function")
      end
      local writer = self:make_template_writer()
      local template_args
      if tpl.argparser then
        local parse_args = tpl.argparser()
        template_args = {
          parse_args:parse(args.template_args)
        }
      elseif tpl.check_args then
        tpl.check_args(unpack(args.template_args))
        template_args = args.template_args
      end
      return tpl.write(writer, unpack(template_args))
    end
  },
  {
    name = "simulate",
    help = "Execute a mock HTTP request to your application code without any server involved",
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:argument("path", "Path to request, may include query parameters (eg. /)")
        _with_0:option("--app-class", "Override default app class module name")
        _with_0:option("--helper", "Module name to require before loading app")
        _with_0:group("Request control", _with_0:option("--method", "HTTP method"):choices({
          "GET",
          "POST",
          "PUT",
          "DELETE",
          "OPTIONS",
          "HEAD",
          "PATCH"
        }):default("GET"), _with_0:option("--body", "Body of request, - for stdin"), _with_0:option("--form -F", "Set method to POST if unset, content type to application/x-www-form-urlencoded, and body to value of this option"):count("*"), _with_0:option("--header -H", "Append an input header, can be used multiple times (can overwrite set headers from other options"):count("*"), _with_0:option("--host", "Set the host header of request"), _with_0:option("--scheme", "Override default scheme (eg. https, http)"), _with_0:flag("--json", "Set accept header to application/json"), _with_0:flag("--csrf", "Set generated CSRF header and parameter for form requests"))
        _with_0:group("Display options", _with_0:flag("--print-headers", "Print only the headers as JSON"), _with_0:flag("--print-json", "Print the entire response as JSON"))
        return _with_0
      end
    end,
    function(self, args)
      local set_default_environment
      set_default_environment = require("lapis.environment").set_default_environment
      set_default_environment(args.environment)
      if args.helper then
        require(args.helper)
      end
      local config = require("lapis.config").get()
      local app_module = args.app_class or config.app_class or "app"
      local app_cls = require(app_module or config.app_class)
      local mock_request
      mock_request = require("lapis.spec.request").mock_request
      local input_headers, input_cookies
      if args.json then
        input_headers = input_headers or { }
        input_headers["Accept"] = "application/json"
      end
      if args.body == "-" then
        args.body = io.stdin:read("*a")
      end
      if args.csrf then
        local generate_token
        generate_token = require("lapis.csrf").generate_token
        args.form = args.form or { }
        input_cookies = input_cookies or { }
        local encode_query_string
        encode_query_string = require("lapis.util").encode_query_string
        table.insert(args.form, encode_query_string({
          csrf_token = generate_token({
            cookies = input_cookies
          })
        }))
      end
      if args.form and next(args.form) then
        input_headers = input_headers or { }
        input_headers["Content-Type"] = "application/x-www-form-urlencoded"
        if args.method == "GET" then
          args.method = "POST"
        end
        args.body = table.concat(args.form, "&")
      end
      if args.header and next(args.header) then
        local _list_0 = args.header
        for _index_0 = 1, #_list_0 do
          local _continue_0 = false
          repeat
            local row = _list_0[_index_0]
            local name, value = row:match("([^:]+):%s*(.+)")
            if not (name) then
              _continue_0 = true
              break
            end
            input_headers = input_headers or { }
            input_headers[name] = value
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
      end
      local request_options = {
        method = args.method,
        host = args.host,
        body = args.body,
        headers = input_headers,
        cookies = input_cookies,
        scheme = args.scheme
      }
      local status, response, headers = assert(mock_request(app_cls, args.path, request_options))
      if args.print_json then
        local to_json
        to_json = require("lapis.util").to_json
        local extract_cookies
        extract_cookies = require("lapis.spec.request").extract_cookies
        local session
        do
          local response_cookies = extract_cookies(headers)
          if response_cookies then
            local get_session
            get_session = require("lapis.session").get_session
            session = get_session({
              cookies = response_cookies
            })
          end
        end
        return print(to_json({
          status = status,
          response = response,
          headers = headers,
          session = session
        }))
      elseif args.print_headers then
        local to_json
        to_json = require("lapis.util").to_json
        return print(to_json(headers))
      else
        colors = require("ansicolors")
        io.stderr:write(colors("%{green}Status%{reset}: " .. tostring(status) .. "\n"))
        local header_names
        do
          local _accum_0 = { }
          local _len_0 = 1
          for k in pairs(headers) do
            _accum_0[_len_0] = k
            _len_0 = _len_0 + 1
          end
          header_names = _accum_0
        end
        table.sort(header_names)
        for _index_0 = 1, #header_names do
          local h = header_names[_index_0]
          local h_value = headers[h]
          if type(h_value) ~= "table" then
            h_value = {
              tostring(h_value)
            }
          end
          for _index_1 = 1, #h_value do
            local v = h_value[_index_1]
            io.stderr:write(colors("%{yellow}" .. tostring(h) .. "%{reset}: " .. tostring(v) .. "\n"))
          end
        end
        return print(response)
      end
    end
  },
  {
    name = "_",
    hidden = true,
    help = "Excute third-party command from module lapis.cmd.actions._",
    argparse = function(command)
      do
        local _with_0 = command
        _with_0:handle_options(false)
        _with_0:argument("sub_command", "Which command module to load"):argname("<command>")
        _with_0:argument("sub_command_args", "Arguments to command"):argname("<args>"):args("*")
        return _with_0
      end
    end,
    function(self, args)
      local _exp_0 = args.sub_command
      if "--help" == _exp_0 or "-h" == _exp_0 then
        return self:execute({
          "help",
          "_"
        })
      end
      local action = require("lapis.cmd.actions." .. tostring(args.sub_command))
      local command_args
      if action.argparser then
        local parse_args = action.argparser()
        command_args = {
          parse_args:parse(args.sub_command_args),
          args
        }
      else
        parse_flags = require("lapis.cmd.util").parse_flags
        local flags, rest = parse_flags(args.sub_command_args)
        flags.environment = flags.environment or args.environment
        command_args = {
          flags,
          unpack(rest)
        }
      end
      return action[1](self, unpack(command_args))
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
        add_environment_argument(command, "Environment to create service file for")
        _with_0:flag("--install", "Installs the service file to the system, requires sudo permission")
        return _with_0
      end
    end,
    function(self, args)
      local action = require("lapis.cmd.actions.systemd")
      return action[1](self, args, args.sub_command, args.environment)
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
        _with_0:handle_options(false)
        _with_0:argument("sub_command_args", "Arguments to command"):argname("<args>"):args("*")
        return _with_0
      end
    end,
    function(self, args)
      local action = require("lapis.cmd.actions.annotate")
      assert(action.argparser, "Your lapis-annotate module is too out of date for this version of Lapis, please update it")
      local parse_args = action.argparser()
      return action[1](self, parse_args:parse(args.sub_command_args), args)
    end
  },
  {
    name = "debug",
    hidden = true,
    help = "Debug information for test sutie",
    test_available = function()
      local running_in_test
      running_in_test = require("lapis.spec").running_in_test
      return running_in_test()
    end,
    argparse = function(command)
      return add_environment_argument(command)
    end,
    function(self, args)
      return args
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
      local de = default_environment()
      local parser = argparse("lapis", table.concat({
        "Control & create web applications written with Lapis",
        colors("Lapis: %{bright}" .. tostring(require("lapis.version"))),
        (function()
          if de == "development" then
            return colors("Default environment: %{yellow}" .. tostring(de))
          else
            return colors("Default environment: %{bright green}" .. tostring(de))
          end
        end)(),
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
      parser:option("--environment", "Override the environment name"):argname("<name>")
      parser:option("--config-module", "Override module name to require configuration from (default: config)"):argname("<name>")
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
    make_template_writer = function(self)
      return {
        command_runner = self,
        write = function(_, ...)
          local success, err = self:write_file_safe(...)
          if not (success) then
            return self:fail_with_message(err)
          end
        end,
        mod_to_path = function(self, mod)
          return mod:gsub("%.", "/")
        end,
        default_language = default_language()
      }
    end,
    write_file_safe = function(self, file, content)
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
      assert(action, "Failed to find command: " .. tostring(args.command))
      if args.config_module then
        package.loaded["lapis.config_module_name"] = args.config_module
      end
      if action.context then
        assert(self:check_context(args.environment, action.context))
      end
      if not (args.environment) then
        local default_environment
        default_environment = require("lapis.environment").default_environment
        args.environment = default_environment()
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
    get_config = function(self, environment)
      return require("lapis.config").get(environment)
    end,
    get_server_type = function(self, environment)
      return (assert(self:get_config(environment).server, "Failed to get server type from config (did you set `server`?)"))
    end,
    get_server_module = function(self, environment)
      return require("lapis.cmd." .. tostring(self:get_server_type(environment)))
    end,
    get_server_actions = function(self, environment)
      return require("lapis.cmd." .. tostring(self:get_server_type(environment)) .. ".actions")
    end,
    check_context = function(self, environment, contexts)
      local s = self:get_server_module(environment)
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
local command_runner = CommandRunner()
return {
  command_runner = command_runner,
  get_command = (function()
    local _base_0 = command_runner
    local _fn_0 = _base_0.get_command
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  execute = (function()
    local _base_0 = command_runner
    local _fn_0 = _base_0.execute_safe
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)()
}
