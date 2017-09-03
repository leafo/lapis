local default_environment, columnize, parse_flags, write_file_safe
do
  local _obj_0 = require("lapis.cmd.util")
  default_environment, columnize, parse_flags, write_file_safe = _obj_0.default_environment, _obj_0.columnize, _obj_0.parse_flags, _obj_0.write_file_safe
end
local colors = require("ansicolors")
local Actions
do
  local _class_0
  local _base_0 = {
    defalt_action = "help",
    format_error = function(self, msg)
      return colors("%{bright red}Error:%{reset} " .. tostring(msg))
    end,
    fail_with_message = function(self, msg)
      print(colors("%{bright}%{red}Aborting:%{reset} " .. msg))
      return os.exit(1)
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
    execute = function(self, args)
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
      local action_name = plain_args[1] or self.defalt_action
      local action = self:get_action(action_name)
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
        print(self:format_error("unknown command `" .. tostring(action_name) .. "'"))
        self:get_action("help")[1](self, unpack(rest))
        return 
      end
      local fn = assert(action[1], "action `" .. tostring(action_name) .. "' not implemented")
      assert(self:check_context(action.context))
      return fn(self, flags, unpack(rest))
    end,
    execute_safe = function(self, args)
      local trace = false
      for _index_0 = 1, #args do
        local v = args[_index_0]
        if v == "--trace" then
          trace = true
        end
      end
      if trace then
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
    get_server_type = function(self)
      local config = require("lapis.config").get()
      return config.server
    end,
    get_server_module = function(self)
      return require("lapis.cmd." .. tostring(self:get_server_type()))
    end,
    get_server_actions = function(self)
      return require("lapis.cmd." .. tostring(self:get_server_type()) .. ".actions")
    end,
    check_context = function(self, contexts)
      if not (contexts) then
        return true
      end
      local s = self:get_server_module()
      for _index_0 = 1, #contexts do
        local c = contexts[_index_0]
        if c == s.type then
          return true
        end
      end
      return nil, "command not available for selected server (using " .. tostring(s.type) .. ", needs " .. tostring(table.concat(contexts, ", ")) .. ")"
    end,
    get_action = function(self, name)
      for k, v in ipairs(self.actions) do
        if v.name == name then
          return v
        end
      end
      local action
      pcall(function()
        action = require("lapis.cmd.actions." .. tostring(name))
      end)
      return action
    end,
    actions = {
      {
        name = "new",
        help = "create a new lapis project in the current directory",
        function(self, flags)
          local server_actions
          if flags.cqueues then
            server_actions = require("lapis.cmd.cqueues.actions")
          else
            server_actions = require("lapis.cmd.nginx.actions")
          end
          server_actions.new(self, flags)
          if flags.lua then
            self:write_file_safe("app.lua", require("lapis.cmd.templates.app_lua"))
            self:write_file_safe("models.lua", require("lapis.cmd.templates.models_lua"))
          else
            self:write_file_safe("app.moon", require("lapis.cmd.templates.app"))
            self:write_file_safe("models.moon", require("lapis.cmd.templates.models"))
          end
          if flags.git then
            self:write_file_safe(".gitignore", require("lapis.cmd.templates.gitignore")(flags))
          end
          if flags.tup then
            local tup_files = require("lapis.cmd.templates.tup")
            for fname, content in pairs(tup_files) do
              self:write_file_safe(fname, content)
            end
          end
        end
      },
      {
        name = "server",
        usage = "server [environment]",
        help = "build config and start server",
        function(self, flags, environment)
          if environment == nil then
            environment = default_environment()
          end
          return self:get_server_actions().server(self, flags, environment)
        end
      },
      {
        name = "build",
        usage = "build [environment]",
        help = "build config, send HUP if server running",
        context = {
          "nginx"
        },
        function(self, flags, environment)
          if environment == nil then
            environment = default_environment()
          end
          local write_config_for
          write_config_for = require("lapis.cmd.nginx").write_config_for
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
        help = "sends TERM signal to shut down a running server",
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
        help = "send arbitrary signal to running server",
        context = {
          "nginx"
        },
        function(self, flags, signal)
          assert(signal, "Missing signal")
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
        usage = "exec <lua-string>",
        help = "execute Lua on the server",
        context = {
          "nginx"
        },
        function(self, flags, code, environment)
          if environment == nil then
            environment = default_environment()
          end
          if not (code) then
            self:fail_with_message("missing lua-string: exec <lua-string>")
          end
          local attach_server, get_pid
          do
            local _obj_0 = require("lapis.cmd.nginx")
            attach_server, get_pid = _obj_0.attach_server, _obj_0.get_pid
          end
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
        function(self, flags, environment)
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
        function(self, flags, template_name, ...)
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
        function(self)
          print(colors("Lapis " .. tostring(require("lapis.version"))))
          print("usage: lapis <action> [arguments]")
          local find_nginx
          find_nginx = require("lapis.cmd.nginx").find_nginx
          local nginx = find_nginx()
          if nginx then
            print("using nginx: " .. tostring(nginx))
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
            local _list_0 = self.actions
            for _index_0 = 1, #_list_0 do
              local t = _list_0[_index_0]
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
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.path = require("lapis.cmd.path")
      self.path = self.path:annotate()
    end,
    __base = _base_0,
    __name = "Actions"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Actions = _class_0
end
local actions = Actions()
return {
  actions = actions,
  get_action = (function()
    local _base_0 = actions
    local _fn_0 = _base_0.get_action
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
