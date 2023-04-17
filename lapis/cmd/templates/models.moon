argparser = ->
  with require("argparse") "lapis generate application", "Generate a models loader module"
    \option("--models-module --module", "The module name of the generated application")\default "models"

    \mutex(
      \flag "--lua", "Force output to be Lua"
      \flag "--moonscript --moon", "Force output to be MoonScript"
    )

initial_moon = [[
import autoload from require "lapis.util"
autoload "models"
]]

initial_lua = [[
local autoload = require("lapis.util").autoload
return autoload("models")
]]

write = (args) =>
  output_language = if args.lua
    "lua"
  elseif args.moonscript
    "moonscript"
  else
    @default_language

  module_base_path = @mod_to_path args.models_module

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

