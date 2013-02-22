
filters = {
  pg: (url) ->
    user, password, host, db = url\match "^postgres://(.*):(.*)@(.*)/(.*)$"
    error "failed to parse postgres server url" unless user
    "%s dbname=%s user=%s password=%s"\format host, db, user, password
}

compile_config = (config, opts={}) ->
  env = setmetatable {}, __index: (key) =>
    v = os.getenv "LAPIS_" .. key\upper!
    return v if v != nil
    opts[key]

  out = config\gsub "(${%b{}})", (w) ->
    name = w\sub 4, -3
    filter_name, filter_arg = name\match("^(%S*)%s*(.*)$")
    if filter = filters[filter_name]
      value = env[filter_name]
      if value == nil then w else filter value
    else
      value = env[name]
      if value == nil then w else value
  out

if ... == "test"
  str = [[
    hello: ${{some_var}}
  ]]
  print compile_config str, { some_var: "what's up" }

{ :compile_config, :filters }
