import insert, concat from table

argparser = ->
  with require("argparse") "lapis generate gitignore", "Generate a .gitignore file"
    \flag "--tup"

    \mutex(
      \flag "--cqueues"
      \flag "--nginx"
    )

    \mutex(
      \flag "--lua"
      \flag "--moonscript --moon"
    )

write = (args) =>
  lines = {}

  if args.nginx
    insert lines, "logs/"
    insert lines, "nginx.conf.compiled"

  if args.moonscript
    insert lines, "*.lua"

  if args.tup
    insert lines, ".tup"

  output = concat(lines, "\n") .. "\n"

  @write ".gitignore", output

{:argparser, :write}
