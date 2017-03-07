import insert, concat from table

(flags={}) ->
  lines = {
    "logs/"
    "nginx.conf.compiled"
  }
  
  if not flags.lua
    insert lines, "*.lua"

  if flags.tup
    insert lines, ".tup"

  concat(lines, "\n") .. "\n"
