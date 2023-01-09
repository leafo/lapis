return {
  new = function(self, args)
    local writer = self:make_template_writer()
    local config_tpl = require("lapis.cmd.cqueues.templates.config")
    return config_tpl.write(writer, setmetatable({
      server = "cqueues"
    }, {
      __index = args
    }))
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
