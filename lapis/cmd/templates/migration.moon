-- this does two things: 1. if migration file is detected, insert a new
-- migration at the end of the migrations module file if no migration file is
-- detected, create a blank one and insert the first migration

argparser = ->
  with require("argparse") "lapis generate migration", "Create a slot for a new empty migration, or generate a new one"
    \option("--counter", "Naming convention for new migration")\choices({"timestamp"})\default "timestamp"

    \mutex(
      \flag "--lua", "Force editing/creating Lua file"
      \flag "--moonscript --moon", "Force editing/creating MoonScript file"
    )

empty_lua = [[
local db = reuqire("lapis.db")
local schema = require("lapis.db.schema")

return {
  [%s]: function()
  end
}
]]

empty_moon = [[
db = require "lapis.db"
schema = require "lapis.db.schema"

{
  [%s]: =>
}
]]

write = (args) =>
  output_language = if args.lua
    "lua"
  elseif args.moonscript
    "moonscript"
  else
    @default_language

  output_fname = switch output_language
    when "lua"
      "migrations.lua"
    when "moonscript"
      "migrations.moon"

  have_file = @command_runner.path.exists output_fname
  if have_file
    error "TODO: have migrations file: #{output_fname}, edit me"
  else
    next_name = switch args.counter
      when "timestamp"
        tostring os.time!
      else
        error "Don't know how to get next name"

    switch output_language
      when "lua"
        @write output_fname, empty_lua\format next_name
      when "moonscript"
        @write output_fname, empty_moon\format next_name

{:write, :argparser}
