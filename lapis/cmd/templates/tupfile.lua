local argparser
argparser = function()
  return require("argparse")("lapis generate tupfile", "Generate a Tupfile and Tuprules.tup file")
end
local initial_tupfile = [[include_rules
]]
local initial_tuprules = [[TOP = $(TUP_CWD)

.gitignore

: foreach *.moon |> moonc %f |> %B.lua $(TOP)/<moon>
]]
local write
write = function(self, args)
  self:write("Tupfile", initial_tupfile)
  return self:write("Tuprules.tup", initial_tuprules)
end
return {
  argparser = argparser,
  write = write
}
