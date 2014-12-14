local colors = require("ansicolors")
local insert
insert = table.insert
local config = require("lapis.config").get()
local flatten_params_helper, flatten_params, query, request, migration, notice, migration_summary
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
query = function(q)
  local l = config.logging
  if not (l and l.queries) then
    return 
  end
  return print(colors("%{bright}%{cyan}SQL: %{reset}%{magenta}" .. tostring(q) .. "%{reset}"))
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
  local cmd = tostring(req.cmd_mth) .. " " .. tostring(req.cmd_url)
  return print(colors(t):format(status, cmd, flatten_params(r.url_params)))
end
migration = function(name)
  return print(colors("%{bright}%{yellow}Migrating: %{reset}%{green}" .. tostring(name) .. "%{reset}"))
end
notice = function(msg)
  return print(colors("%{bright}%{yellow}Notice: %{reset}" .. tostring(msg)))
end
migration_summary = function(count)
  local noun
  if count == 1 then
    noun = "migration"
  else
    noun = "migrations"
  end
  return print(colors("%{bright}%{yellow}Ran%{reset} " .. tostring(count) .. " %{bright}%{yellow}" .. tostring(noun)))
end
return {
  request = request,
  query = query,
  migration = migration,
  migration_summary = migration_summary,
  notice = notice,
  flatten_params = flatten_params
}
