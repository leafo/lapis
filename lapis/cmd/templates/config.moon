argparser = ->
  with require("argparse") "lapis generate config", "Generate a config module for lapis applications"
    \option("--config-module --module", "The module name of the migrations file")\default "config"

    \mutex(
      \flag "--cqueues", "Configured for cqueues/lua-http server"
      \flag "--nginx", "Configured for nginx server"
    )

    \mutex(
      \flag "--lua", "Create a Lua module for config"
      \flag "--moonscript --moon", "Create a MoonScript module for config"
    )

initial_moon_nginx = [[
import config from require "lapis.config"

config "development", ->
  server "nginx"
  code_cache "off"
  num_workers "1"
]]

initial_lua_nginx = [[
local config = require("lapis.config")

config("development", {
  server = "nginx",
  code_cache = "off",
  num_workers = "1"
})
]]

initial_moon_cqueues = [[
import config from require "lapis.config"

config "development", ->
  server "cqueues"
]]

initial_lua_cqueues = [[
local config = require("lapis.config")

config("development", {
  server = "cqueues"
})
]]

{
  :argparser

  write: (args) =>
    output_language = if args.lua
      "lua"
    elseif args.moonscript
      "moonscript"
    else
      @default_language

    output_fname = @mod_to_path args.config_module, output_language

    output = switch output_language
      when "lua"
        if args.nginx
          initial_lua_nginx
        elseif args.cqueues
          initial_lua_cqueues
      when "moonscript"
        if args.nginx
          initial_moon_nginx
        elseif args.cqueues
          initial_moon_cqueues
      else
        error "Unknown language: #{output_language}"

    assert output, "lapis generate requires a server to be selected to generate config, see lapis generate config --help"
    @write output_fname, output
}
