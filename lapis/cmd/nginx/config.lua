local ConfigCompiler
do
  local _class_0
  local _base_0 = {
    filters = {
      pg = function(val)
        local user, password, host, db
        local _exp_0 = type(val)
        if "table" == _exp_0 then
          db = assert(val.database, "missing database name")
          user, password, host, db = val.user or "postgres", val.password or "", val.host or "127.0.0.1", db
        elseif "string" == _exp_0 then
          user, password, host, db = val:match("^postgres://(.*):(.*)@(.*)/(.*)$")
        end
        if not (user) then
          error("failed to create postgres connect string")
        end
        return ("%s dbname=%s user=%s password=%s"):format(host, db, user, password)
      end
    },
    wrap_environment = function(self, env)
      return setmetatable({ }, {
        __index = function(self, key)
          local v = os.getenv("LAPIS_" .. key:upper())
          if v ~= nil then
            return v
          end
          return env[key:lower()]
        end
      })
    end,
    lookup_value = function(self, env, name)
      if not (name and #name > 0) then
        return nil
      end
      local current = env
      for segment in name:gmatch("[^%.]+") do
        if type(current) ~= "table" then
          return nil
        end
        current = current[segment]
      end
      return current
    end,
    add_config_header = function(self, compiled, env)
      local header
      do
        local name = env._name
        if name then
          header = "env LAPIS_ENVIRONMENT=" .. tostring(name) .. ";\n"
        else
          header = "env LAPIS_ENVIRONMENT;\n"
        end
      end
      return header .. compiled
    end,
    compile_config = function(self, config, env, opts)
      if env == nil then
        env = { }
      end
      if opts == nil then
        opts = { }
      end
      local wrapped_env = opts.os_env == false and env or self:wrap_environment(env)
      local out = config:gsub("(${%b{}})", function(variable_exp)
        local name = variable_exp:sub(4, -3)
        local filter_name, filter_arg = name:match("^(%S+)%s+(.+)$")
        local value
        do
          local filter = self.filters[filter_name]
          if filter then
            value = filter(self:lookup_value(wrapped_env, filter_arg))
          else
            value = self:lookup_value(wrapped_env, name)
          end
        end
        if value == nil then
          return variable_exp
        else
          return tostring(value)
        end
      end)
      if opts.header == false then
        return out
      else
        return self:add_config_header(out, env)
      end
    end,
    compile_etlua_config = function(self, config, env, opts)
      if env == nil then
        env = { }
      end
      if opts == nil then
        opts = { }
      end
      local etlua = require("etlua")
      local wrapped = opts.os_env == false and env or self:wrap_environment(env)
      local template = assert(etlua.compile(config))
      local out = template(wrapped)
      if opts.header == false then
        return out
      else
        return self:add_config_header(out, env)
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "ConfigCompiler"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  ConfigCompiler = _class_0
end
return {
  ConfigCompiler = ConfigCompiler
}
