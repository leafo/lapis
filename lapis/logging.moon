
colors = require "ansicolors"
import insert from table

flatten_params_helper = (params, out = {}, sep= ", ")->
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

request = (r) ->
  import req, res from r
  status = if res.statusline then res.statusline\match " (%d+) " else "200"
  t = "[%{green}%s%{reset}] %{bright}%{cyan}%s%{reset} - %s"

  cmd = "#{req.cmd_mth} #{req.cmd_url}"
  print colors(t)\format status, cmd, flatten_params r.url_params

{ :request }

