local unpack = unpack or table.unpack
return {
  new = function(self, args, template_flags)
    local valid_install = pcall(function()
      require("cqueues")
      return require("http.version")
    end)
    if not valid_install and not args.force then
      self:fail_with_message("Unable to load necessary modules for server. Please use LuaRocks to install `cqueues` and `http` modules. You can bypass this error with --force")
    end
    return self:execute({
      "generate",
      "config",
      "--cqueues",
      unpack(template_flags)
    })
  end,
  server = function(self, args)
    local environment
    environment = args.environment
    local push, pop
    do
      local _obj_0 = require("lapis.environment")
      push, pop = _obj_0.push, _obj_0.pop
    end
    local start_server
    start_server = require("lapis.cmd.cqueues").start_server
    push(environment)
    local config = require("lapis.config").get()
    local app_module = config.app_class or "app"
    start_server(app_module)
    return pop()
  end
}
