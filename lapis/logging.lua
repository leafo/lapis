local _print
if ngx then
  _print = print
else
  _print = function(...)
    return io.stderr:write(table.concat({
      ...
    }, "\t") .. "\n")
  end
end
local set_print
set_print = function(p)
  _print = p
end
local colors = require("ansicolors")
local insert
insert = table.insert
local config = require("lapis.config").get()
local flatten_params_helper, flatten_params, query, request, migration, notice, migration_summary, start_server
flatten_params_helper = function(params, out, sep)
  if out == nil then
    out = { }
  end
  if sep == nil then
    sep = ", "
  end
  if not (params) then
    return {
      "{}"
    }
  end
  insert(out, "{ ")
  for k, v in pairs(params) do
    insert(out, tostring(k))
    insert(out, ": ")
    if type(v) == "table" then
      flatten_params(v, out)
    else
      insert(out, ("%q"):format(v))
    end
    insert(out, sep)
  end
  if out[#out] == sep then
    out[#out] = nil
  end
  insert(out, " }")
  return out
end
flatten_params = function(params)
  return table.concat(flatten_params_helper(params))
end
do
  local log_tpl = colors("%{bright}%{cyan}%s:%{reset} %{magenta}%s")
  local log_tpl_time = colors("%{bright}%{cyan}%s:%{reset} %{yellow}(%s) %{magenta}%s")
  local force_logging = os.getenv("LAPIS_SHOW_QUERIES")
  query = function(query, duration, prefix)
    if prefix == nil then
      prefix = "SQL"
    end
    if not (force_logging) then
      local l = config.logging
      if not (l and l.queries) then
        return 
      end
    end
    if force_logging == "0" then
      return 
    end
    if duration then
      return _print(log_tpl_time:format(prefix, ("%.2fms"):format(duration * 1000), query))
    else
      return _print(log_tpl:format(prefix, query))
    end
  end
end
request = function(r)
  local l = config.logging
  if not (l and l.requests) then
    return 
  end
  local req, res
  req, res = r.req, r.res
  local status
  if res.statusline then
    status = res.statusline:match(" (%d+) ")
  else
    status = res.status or "200"
  end
  status = tostring(status)
  local status_color
  if status:match("^2") then
    status_color = "green"
  elseif status:match("^5") then
    status_color = "red"
  else
    status_color = "yellow"
  end
  local t = "[%{" .. tostring(status_color) .. "}%s%{reset}] %{bright}%{cyan}%s%{reset} - %s"
  local cmd = tostring(req.method) .. " " .. tostring(req.request_uri)
  return _print(colors(t):format(status, cmd, flatten_params(r.url_params)))
end
do
  local log_tpl = colors("%{bright}%{yellow}Migrating: %{reset}%{green}%s%{reset}")
  migration = function(name)
    return _print(log_tpl:format(name))
  end
end
do
  local log_tpl = colors("%{bright}%{yellow}Notice: %{reset}%s")
  notice = function(msg)
    return _print(log_tpl:format(msg))
  end
end
migration_summary = function(count)
  local noun
  if count == 1 then
    noun = "migration"
  else
    noun = "migrations"
  end
  return _print(colors("%{bright}%{yellow}Ran%{reset} " .. tostring(count) .. " %{bright}%{yellow}" .. tostring(noun)))
end
start_server = function(port, environment_name)
  local l = config.logging
  if not (l and l.server) then
    return 
  end
  print(colors("%{bright}%{yellow}Listening on port " .. tostring(port) .. "%{reset}"))
  if environment_name then
    return print(colors("%{bright}%{yellow}Environment: " .. tostring(environment_name) .. "%{reset}"))
  end
end
return {
  request = request,
  query = query,
  migration = migration,
  migration_summary = migration_summary,
  notice = notice,
  flatten_params = flatten_params,
  start_server = start_server,
  set_print = set_print
}
