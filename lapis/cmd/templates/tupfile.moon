
argparser = ->
  require("argparse") "lapis generate tupfile", "Generate a Tupfile and Tuprules.tup file"

initial_tupfile = [[
include_rules
]]

initial_tuprules = [[
TOP = $(TUP_CWD)

.gitignore

: foreach *.moon |> moonc %f |> %B.lua $(TOP)/<moon>
]]

write = (args) =>
  @write "Tupfile", initial_tupfile
  @write "Tuprules.tup", initial_tuprules

{
  :argparser, :write
}
