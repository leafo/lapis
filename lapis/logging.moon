
colors = require "ansicolors"
import insert from table

flatten_params_helper = (params, out = {}, sep= ", ")->
  return {"{}"} unless params

  insert out, "{ "
  for k,v in pairs params
    insert out, tostring k
    insert out, ": "
    if type(v) == "table"
      flatten_params v, out
    else
      insert out, ("%q")\format v
    insert out, sep

  -- remove last ", "
  out[#out] = nil if out[#out] == sep

  insert out, " }"
  out


flatten_params = (params) ->
  table.concat flatten_params_helper params

query = (q) ->
  print colors("%{bright}%{cyan}SQL: %{reset}%{magenta}#{q}%{reset}")

request = (r) ->
  import req, res from r

  status = if res.statusline
    res.statusline\match " (%d+) "
  else
    res.status or "200"

  status = tostring status
  status_color = if status\match "^2"
    "green"
  elseif status\match "^5"
    "red"
  else
    "yellow"

  t = "[%{#{status_color}}%s%{reset}] %{bright}%{cyan}%s%{reset} - %s"

  cmd = "#{req.cmd_mth} #{req.cmd_url}"
  print colors(t)\format status, cmd, flatten_params r.url_params

{ :request, :query }

