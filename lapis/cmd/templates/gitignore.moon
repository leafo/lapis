import insert, concat from table

(flags={}) ->
  lines = {
    "*.lua"
    "logs/"
    "nginx.conf.compiled"
  }

  if flags.tup
    insert lines, ".tup"

  concat(lines, "\n") .. "\n"
