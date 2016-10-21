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
    local cls = config.app_class or "app"
    local app_cls = require(cls)
    local app
    if app_cls.__base then
      app = app_cls()
    else
      app_cls:build_router()
      app = app_cls
    end
    start_server(app)
    return pop()
  end
}
