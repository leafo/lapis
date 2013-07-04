local find_nginx
do
  local nginx_bin = "nginx"
  local nginx_search_paths = {
    "/usr/local/openresty/nginx/sbin/",
    "/usr/sbin/",
    ""
  }
  local nginx_path
  find_nginx = function()
    if nginx_path then
      return nginx_path
    end
    for _index_0 = 1, #nginx_search_paths do
      local prefix = nginx_search_paths[_index_0]
      local cmd = tostring(prefix) .. tostring(nginx_bin) .. " -v 2>&1"
      local handle = io.popen(cmd)
      local out = handle:read()
      handle:close()
      if out:match("^nginx version: ngx_openresty/") then
        nginx_path = tostring(prefix) .. tostring(nginx_bin)
        return nginx_path
      end
    end
  end
end
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
      return opts[key:lower()]
    end
  })
  local out = config:gsub("(${%b{}})", function(w)
    local name = w:sub(4, -3)
    local filter_name, filter_arg = name:match("^(%S+)%s+(.+)$")
    do
      local filter = filters[filter_name]
      if filter then
        local value = env[filter_arg]
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
local get_pid
get_pid = function()
  local pidfile = io.open("logs/nginx.pid")
  if not (pidfile) then
    return 
  end
  local pid = pidfile:read("*a")
  pidfile:close()
  return pid:match("[^%s]+")
end
local send_hup
send_hup = function()
  do
    local pid = get_pid()
    if pid then
      os.execute("kill -HUP " .. tostring(pid))
      return pid
    end
  end
end
return {
  compile_config = compile_config,
  filters = filters,
  find_nginx = find_nginx,
  send_hup = send_hup,
  get_pid = get_pid
}
