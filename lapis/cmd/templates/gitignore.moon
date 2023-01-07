import insert, concat from table

(flags={}) ->
  lines = {}

  if flags.server != "cqueues"
    insert lines, "logs/"
    insert lines, "nginx.conf.compiled"

  if flags.moonscript
    insert lines, "*.lua"

  if flags.tup
    insert lines, ".tup"

  concat(lines, "\n") .. "\n"
