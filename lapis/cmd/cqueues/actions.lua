return {
  new = function(self, flags) end,
  server = function(self, flags, environment)
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
