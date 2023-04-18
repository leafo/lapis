-- this does two things: 1. if migration file is detected, insert a new
-- migration at the end of the migrations module file if no migration file is
-- detected, create a blank one and insert the first migration

argparser = ->
  with require("argparse") "lapis generate migration", "Generate a migrations file if necessary, and append a new migration to the file"
    \option("--counter", "Naming convention for new migration")\choices({"timestamp", "increment"})\default "timestamp"
    \option("--migrations-module --module", "The module name of the migrations file")\default "migrations"

    \mutex(
      \flag "--lua", "Force editing/creating Lua file"
      \flag "--moonscript --moon", "Force editing/creating MoonScript file"
    )

initial_lua = [[
local db = require("lapis.db")
local schema = require("lapis.db.schema")

return {
  [%s] = function()
  end
}
]]

empty_lua = [[
  [%s] = function()
  end]]

initial_moon = [[
db = require "lapis.db"
schema = require "lapis.db.schema"

{
  [%s]: =>
}
]]

empty_moon = [[
  [%s]: =>]]

insert_end_lua = (input, insertion) ->
  import P, S, Cc, Cs from require "lpeg"
  whitespace = S" \t\n\r"
  file_tail = whitespace * P"}" * whitespace^0 * P -1
  pattern = Cs (1 - file_tail)^0 * Cc(",\n" .. insertion) * file_tail
  pattern\match input

insert_end_moon = (input, insertion) ->
  import P, S, Cc, Cs from require "lpeg"
  whitespace = S" \t\n\r"
  file_tail = P"}" * whitespace^0 * P -1
  pattern = (1 - file_tail)^0 * Cc("\n#{insertion}\n") * file_tail

  -- alternate pattern that just inserted it end of file
  alt = P(1)^0 * Cc("\n#{insertion}\n")

  Cs(pattern + alt)\match input

get_next_name  = (counter_type, migrations_module) ->
  switch counter_type
    when "timestamp"
      tostring os.time!
    when "increment"
      unless migrations_module
        return 1

      -- NOTE: with MoonScript, this will require the moon file to be built
      -- otherwise it won't find the module (or could load an outdated one)
      m = require migrations_module

      k = 1
      while true
        unless m[k]
          return k

        k += 1

write = (args) =>
  output_language = if args.lua
    "lua"
  elseif args.moonscript
    "moonscript"
  else
    @default_language

  module_base_path = @mod_to_path args.migrations_module

  output_fname = switch output_language
    when "lua"
      "#{module_base_path}.lua"
    when "moonscript"
      "#{module_base_path}.moon"

  have_file = @command_runner.path.exists output_fname
  if have_file
    current_contents = assert(io.open(output_fname))\read "*a"

    next_name = get_next_name args.counter, args.migrations_module
    edited_contents = switch output_language
      when "lua"
        insert_end_lua current_contents, (empty_lua\format next_name)
      when "moonscript"
        insert_end_moon current_contents, (empty_moon\format next_name)

    assert edited_contents, "Failed to edit the contents of the current migration file. Please ensure it's valid Lua/MoonScript code with a trailing } character"

    @command_runner.path.write_file output_fname, edited_contents
  else
    next_name = get_next_name args.counter

    switch output_language
      when "lua"
        @write output_fname, initial_lua\format next_name
      when "moonscript"
        @write output_fname, initial_moon\format next_name

{:write, :argparser}
