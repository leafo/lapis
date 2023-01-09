local insert
insert = table.insert
local CONFIG_MODULE = package.loaded["lapis.config_module_name"] or "config"
local config_cache, configs, default_config, merge_set, set, scope_meta, config, reset, run_with_scope, get_env, get
config_cache = { }
configs = { }
default_config = {
  port = "8080",
  secret = "please-change-me",
  session_name = "lapis_session",
  server = "nginx",
  code_cache = "off",
  num_workers = "1",
  logging = {
    queries = true,
    requests = true,
    server = true
  }
}
merge_set = function(t, k, v)
  local existing = t[k]
  if type(v) == "table" then
    if type(existing) ~= "table" then
      existing = { }
      t[k] = existing
    end
    for sub_k, sub_v in pairs(v) do
      merge_set(existing, sub_k, sub_v)
    end
  else
    t[k] = v
  end
end
set = function(conf, k, v)
  if type(k) == "table" then
    for sub_k, sub_v in pairs(k) do
      merge_set(conf, sub_k, sub_v)
    end
  else
    if type(v) == "function" then
      return merge_set(conf, k, run_with_scope(v, { }))
    else
      return merge_set(conf, k, v)
    end
  end
end
scope_meta = {
  __index = function(self, name)
    local val = _G[name]
    if not (val == nil) then
      return val
    end
    do
      local _exp_0 = name
      if "set" == _exp_0 then
        val = function(...)
          return set(self._conf, ...)
        end
      elseif "unset" == _exp_0 then
        val = function(...)
          local _list_0 = {
            ...
          }
          for _index_0 = 1, #_list_0 do
            local k = _list_0[_index_0]
            self._conf[k] = nil
          end
        end
      elseif "include" == _exp_0 then
        val = function(fn)
          return run_with_scope(fn, self._conf)
        end
      else
        val = function(v)
          return set(self._conf, name, v)
        end
      end
      self[name] = val
      return val
    end
  end
}
config = function(environment, fn)
  if type(environment) == "table" then
    for _index_0 = 1, #environment do
      local env = environment[_index_0]
      config(env, fn)
    end
    return 
  end
  local _update_0 = environment
  configs[_update_0] = configs[_update_0] or { }
  table.insert(configs[environment], fn)
  return nil
end
reset = function(env)
  if env == true then
    for k in pairs(configs) do
      configs[k] = nil
    end
    for k in pairs(config_cache) do
      config_cache[k] = nil
    end
  else
    configs[env] = nil
    config_cache[env] = nil
  end
end
run_with_scope = function(fn, conf)
  local getfenv, setfenv
  do
    local _obj_0 = require("lapis.util.fenv")
    getfenv, setfenv = _obj_0.getfenv, _obj_0.setfenv
  end
  local old_env = getfenv(fn)
  local env = setmetatable({
    _conf = conf
  }, scope_meta)
  setfenv(fn, env)
  fn()
  setfenv(fn, old_env)
  return conf
end
get_env = function()
  return require("lapis.environment").default_environment()
end
do
  local loaded_config = false
  get = function(name)
    if name == nil then
      name = get_env()
    end
    if not (name) then
      error("missing environment name")
    end
    if not (loaded_config) then
      loaded_config = true
      local success, err = pcall(function()
        return require(CONFIG_MODULE)
      end)
      if not (success or err:match("module '" .. tostring(CONFIG_MODULE) .. "' not found")) then
        error(err)
      end
    end
    if config_cache[name] then
      return config_cache[name]
    end
    local conf
    do
      local _tbl_0 = { }
      for k, v in pairs(default_config) do
        _tbl_0[k] = v
      end
      conf = _tbl_0
    end
    conf._name = name
    do
      local fns = configs[name]
      if fns then
        for _index_0 = 1, #fns do
          local fn = fns[_index_0]
          local _exp_0 = type(fn)
          if "function" == _exp_0 then
            run_with_scope(fn, conf)
          elseif "table" == _exp_0 then
            set(conf, fn)
          end
        end
      end
    end
    config_cache[name] = conf
    return conf
  end
end
return setmetatable({
  get = get,
  config = config,
  merge_set = merge_set,
  default_config = default_config,
  reset = reset
}, {
  __call = function(self, ...)
    return config(...)
  end
})
