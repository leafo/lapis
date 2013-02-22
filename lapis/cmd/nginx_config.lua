local filters = {
  pg = function(url)
    local user, password, host, db = url:match("^postgres://(.*):(.*)@(.*)/(.*)$")
    if not (user) then
      error("failed to parse postgres server url")
    end
    return ("%s dbname=%s user=%s password=%s"):format(host, db, user, password)
  end
}
local compile_config
compile_config = function(config, opts)
  if opts == nil then
    opts = { }
  end
  local env = setmetatable({ }, {
    __index = function(self, key)
      local v = os.getenv("LAPIS_" .. key:upper())
      if v ~= nil then
        return v
      end
      return opts[key]
    end
  })
  local out = config:gsub("(${%b{}})", function(w)
    local name = w:sub(4, -3)
    local filter_name, filter_arg = name:match("^(%S*)%s*(.*)$")
    do
      local filter = filters[filter_name]
      if filter then
        local value = env[filter_name]
        if value == nil then
          return w
        else
          return filter(value)
        end
      else
        local value = env[name]
        if value == nil then
          return w
        else
          return value
        end
      end
    end
  end)
  return out
end
if ... == "test" then
  local str = [[    hello: ${{some_var}}
  ]]
  print(compile_config(str, {
    some_var = "what's up"
  }))
end
return {
  compile_config = compile_config,
  filters = filters
}
