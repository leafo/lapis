
{
  write: (args) =>
    output_language = if args.lua
      "lua"
    elseif args.moonscript
      "moonscript"
    else
      @default_language

    extension = switch output_language
      when "lua"
        "lua"
      when "moonscript"
        "moon"

    output_file = "config.#{extension}"

    output = switch output_language
      when "lua"
        switch args.server
          when "nginx"
            [[
local config = require("lapis.config")

config("development", {
  server = "nginx",
  code_cache = "off",
  num_workers = "1"
})
]]
          when "cqueues"
            [[
local config = require("lapis.config")

config("development", {
  server = "cqueues"
})
]]
      when "moonscript"
        switch args.server
          when "nginx"
            [[
import config from require "lapis.config"

config "development", ->
  server "nginx"
  code_cache "off"
  num_workers "1"
]]
          when "cqueues"
            [[
import config from require "lapis.config"

config "development", ->
  server "cqueues"
  code_cache "off"
  num_workers "1"
]]

    @write output_file, output

}
