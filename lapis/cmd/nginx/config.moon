
class ConfigCompiler
  filters: {
    pg: (val) ->
      user, password, host, db = switch type(val)
        when "table"
          db = assert val.database, "missing database name"
          val.user or "postgres", val.password or "", val.host or "127.0.0.1", db
        when "string"
          val\match "^postgres://(.*):(.*)@(.*)/(.*)$"

      error "failed to create postgres connect string" unless user
      "%s dbname=%s user=%s password=%s"\format host, db, user, password
  }

  wrap_environment: (env) =>
    setmetatable {}, __index: (key) =>
      v = os.getenv "LAPIS_" .. key\upper!
      return v if v != nil
      env[key\lower!]

  lookup_value: (env, name) =>
    return nil unless name and #name > 0
    current = env

    for segment in name\gmatch "[^%.]+"
      if type(current) != "table"
        -- attempting to index filed on non table type, ignore
        return nil

      current = current[segment]

    current

  add_config_header: (compiled, env) =>
    header = if name = env._name
      "env LAPIS_ENVIRONMENT=#{name};\n"
    else
      "env LAPIS_ENVIRONMENT;\n"

    header .. compiled

  compile_config: (config, env={}, opts={}) =>
    wrapped_env = opts.os_env == false and env or @wrap_environment(env)

    out = config\gsub "(${%b{}})", (variable_exp) ->
      name = variable_exp\sub 4, -3
      filter_name, filter_arg = name\match "^(%S+)%s+(.+)$"
      value = if filter = @filters[filter_name]
        filter @lookup_value wrapped_env, filter_arg
      else
        @lookup_value wrapped_env, name

      if value == nil
        -- just return the original without trying to rewrite it
        variable_exp

      else
        tostring value

    if opts.header == false
      out
    else
      @add_config_header out, env

  compile_etlua_config: (config, env={}, opts={}) =>
    etlua = require "etlua"
    wrapped = opts.os_env == false and env or @wrap_environment(env)

    template = assert etlua.compile config

    out = template wrapped

    if opts.header == false
      out
    else
      @add_config_header out, env

{ :ConfigCompiler }
