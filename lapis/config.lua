local insert = table.insert
local default_env, default_config, scope_meta, configs, config, reset, run_with_scope, merge_set, get_env, get
default_env = "development"
default_config = {
  port = "8080",
  secret = "please-change-me",
  session_name = "lapis_session",
  num_workers = "1"
}
scope_meta = {
  __index = (function()
    local set
    set = function(self, k, v)
      if type(k) == "table" then
        for sub_k, sub_v in pairs(k) do
          merge_set(self._conf, sub_k, sub_v)
        end
      else
        if type(v) == "function" then
          self._conf[k] = run_with_scope(v, { })
        else
          return merge_set(self._conf, k, v)
        end
      end
    end
    return function(self, name)
      local val = _G[name]
      if not (val == nil) then
        return val
      end
      do
        local _with_0
        local _exp_0 = name
        if "set" == _exp_0 then
          _with_0 = function(...)
            return set(self, ...)
          end
        elseif "unset" == _exp_0 then
          _with_0 = function(...)
            local _list_0 = {
              ...
            }
            for _index_0 = 1, #_list_0 do
              local k = _list_0[_index_0]
              self._conf[k] = nil
            end
          end
        elseif "include" == _exp_0 then
          _with_0 = function(fn)
            return run_with_scope(fn, self._conf)
          end
        else
          _with_0 = function(v)
            return set(self, name, v)
          end
        end
        val = _with_0
        self[name] = val
        return _with_0
      end
    end
  end)()
}
configs = { }
config = function(environment, fn)
  configs[environment] = configs[environment] or { }
  table.insert(configs[environment], fn)
  return nil
end
reset = function(env)
  if env == true then
    for k in pairs(configs) do
      configs[k] = nil
    end
  else
    configs[env] = nil
  end
end
run_with_scope = function(fn, conf)
  local old_env = getfenv(fn)
  local env = setmetatable({
    _conf = conf
  }, scope_meta)
  setfenv(fn, env)
  fn()
  setfenv(fn, old_env)
  return conf
end
merge_set = function(t, k, v)
  local existing = t[k]
  if existing and type(existing) == "table" and type(v) == "table" then
    for sub_k, sub_v in pairs(v) do
      merge_set(existing, sub_k, sub_v)
    end
  else
    t[k] = v
  end
end
get_env = function()
  return os.getenv("LAPIS_ENVIRONMENT") or default_env
end
do
  local cache = { }
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
        return require("config")
      end)
      if not (success or err:match("module 'config' not found")) then
        error(err)
      end
    end
    if cache[name] then
      return cache[name]
    end
    local conf = (function()
      local _tbl_0 = { }
      for k, v in pairs(default_config) do
        _tbl_0[k] = v
      end
      return _tbl_0
    end)()
    conf._name = name
    do
      local fns = configs[name]
      if fns then
        local _list_0 = fns
        for _index_0 = 1, #_list_0 do
          local fn = _list_0[_index_0]
          run_with_scope(fn, conf)
        end
      end
    end
    cache[name] = conf
    return conf
  end
end
return {
  get = get,
  config = config,
  merge_set = merge_set,
  default_config = default_config,
  reset = reset
}
