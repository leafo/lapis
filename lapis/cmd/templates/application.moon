argparser = ->
  with require("argparse") "lapis generate application", "Generate an empty lapis application module"
    \option("--app-module --module", "The module name of the generated application")\default "app"

    \mutex(
      \flag "--lua", "Force output to be Lua"
      \flag "--moonscript --moon", "Force output to be MoonScript"
    )

initial_moon = [[
lapis = require "lapis"

class extends lapis.Application
  "/": =>
    "Welcome to Lapis #{require "lapis.version"}!"
]]

initial_lua = [[
local lapis = require("lapis")
local app = lapis.Application()

app:get("/", function()
  return "Welcome to Lapis " .. require("lapis.version")
end)

return app
]]

write = (args) =>
  output_language = if args.lua
    "lua"
  elseif args.moonscript
    "moonscript"
  else
    @default_language

  module_base_path = @mod_to_path args.app_module

  output_fname = switch output_language
    when "lua"
      "#{module_base_path}.lua"
    when "moonscript"
      "#{module_base_path}.moon"

  switch output_language
    when "lua"
      @write output_fname, initial_lua
    when "moonscript"
      @write output_fname, initial_moon

{:write, :argparser}

