
import insert from table

CONFIG_MODULE = package.loaded["lapis.config_module_name"] or "config"

local *

config_cache = {} -- the final merged config by environment
configs = {} -- lists of fns/tables to build config by environment

default_config = {
  port: "8080"
  secret: "please-change-me"
  session_name: "lapis_session"
  server: "nginx"

  -- TODO: these fields as part of the default config are now deprecated, and
  -- will be provided in the default generated config with lapis.new
  code_cache: "off"
  num_workers: "1"

  -- optional:
  -- max_request_args: nil
  -- measure_performance: false
  -- mysql: {
  --   backend: "" -- luasql, resty_mysql
  --   host: ""
  --   port: ""
  --   path: "" -- unix domain socket
  --   database: ""
  --   user: ""
  --   ssl: boolean -- for resty_mysql
  --   ssl_verify: boolean -- for resty_mysql
  --   timeout: ms -- for resty_mysql
  --   max_idle_timeout: ms -- for resty_mysql
  --   pool_size: integer -- for resty_mysql
  -- }
  -- postgres: {
  --   backend: ""
  --   host: ""
  --   port: ""
  --   database: ""
  --   user: ""
  -- }

  logging: {
    queries: true
    requests: true
    server: true
  }
}

-- returns "array" for a table of sequential integer keys starting at 1, "map"
-- for a table without [1], "sparse" for integer keys with holes, otherwise
-- "mixed". The # operator isn't used since its result is undefined for tables
-- with holes
table_kind = (t) ->
  return "map" if t[1] == nil
  count = 0
  max = 0
  for k in pairs t
    unless type(k) == "number" and k >= 1 and k % 1 == 0
      return "mixed"

    count += 1
    max = k if k > max

  count == max and "array" or "sparse"

-- maps are merged key by key, arrays replace the existing value, as there's
-- no meaningful way to merge them by index. Mixed tables have no sensible
-- merge, so they are rejected
merge_set = (t, k, v) ->
  unless type(v) == "table"
    t[k] = v
    return

  switch table_kind v
    when "mixed"
      error "config: `#{k}` is a table with both array and hash keys, it can't be merged"
    when "sparse"
      error "config: `#{k}` is an array with missing (nil) values, it can't be merged"
    when "array"
      -- copy so environments configured together don't share a table
      copy = {}
      for i, item in ipairs v
        merge_set copy, i, item

      t[k] = copy
      return

  existing = t[k]
  if type(existing) != "table"
    existing = {}
    t[k] = existing
  elseif table_kind(existing) == "array"
    -- an empty table is treated as an empty array, clearing the existing one
    unless next(v)
      t[k] = {}
      return

    error "config: can't merge hash table into existing array `#{k}`"

  for sub_k, sub_v in pairs v
    merge_set existing, sub_k, sub_v

set = (conf, k, v) ->
  if type(k) == "table"
    for sub_k, sub_v in pairs k
      merge_set conf, sub_k, sub_v
  else
    if type(v) == "function"
      merge_set conf, k, run_with_scope v, {}
    else
      merge_set conf, k, v

scope_meta = {
  __index: (name) =>
    val = _G[name]
    return val unless val == nil

    with val = switch name
        when "set"
          (...) -> set @_conf, ...
        when "unset"
          (...) ->
            for k in *{...}
              @_conf[k] = nil
        when "include"
          (fn) -> run_with_scope fn, @_conf
        else
          (v) -> set @_conf, name, v

      @[name] = val
}

config = (environment, fn) ->
  if type(environment) == "table"
    for env in *environment
      config env, fn
    return

  configs[environment] or= {}
  table.insert configs[environment], fn
  nil

reset = (env) ->
  if env == true
    for k in pairs configs
      configs[k] = nil
    for k in pairs config_cache
      config_cache[k] = nil
  else
    configs[env] = nil
    config_cache[env] = nil

run_with_scope = (fn, conf) ->
  import getfenv, setfenv from require "lapis.util.fenv"

  old_env = getfenv fn
  env = setmetatable { _conf: conf }, scope_meta
  setfenv fn, env
  fn!
  setfenv fn, old_env
  conf

get_env = ->
  require("lapis.environment").default_environment!

get = do
  loaded_config = false
  (name=get_env!) ->
    error "missing environment name" unless name

    unless loaded_config
      loaded_config = true
      success, err = pcall -> require CONFIG_MODULE
      unless success or err\match "module '#{CONFIG_MODULE}' not found"
        error err

    return config_cache[name] if config_cache[name]

    conf = { k,v for k,v in pairs(default_config) }
    conf._name = name
    if fns = configs[name]
      for fn in *fns
        switch type(fn)
          when "function"
            run_with_scope fn, conf
          when "table"
            set conf, fn

    config_cache[name] = conf
    conf

local config_module

---Resolve the application module name. Falls back to `config.default_app_module`, then "app".
---@param override? string Explicit module name to use, bypassing config
---@return string
get_app_module = (override) ->
  -- read get through the module table so a getter replaced by
  -- lapis.environment.push is respected
  override or config_module.get!.default_app_module or "app"

config_module = setmetatable {
  :get, :get_app_module, :config, :merge_set, :default_config, :reset
}, {
  __call: (...) => config ...
}

config_module

