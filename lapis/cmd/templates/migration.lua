local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate migration", "Generate a migrations file if necessary, and append a new migration to the file")
    _with_0:option("--counter", "Naming convention for new migration"):choices({
      "timestamp",
      "increment"
    }):default("timestamp")
    _with_0:option("--migrations-module --module", "The module name of the migrations file"):default("migrations")
    _with_0:mutex(_with_0:flag("--lua", "Force editing/creating Lua file"), _with_0:flag("--moonscript --moon", "Force editing/creating MoonScript file"))
    return _with_0
  end
end
local initial_lua = [[local db = require("lapis.db")
local schema = require("lapis.db.schema")

return {
  [%s] = function()
  end
}
]]
local empty_lua = [[  [%s] = function()
  end]]
local initial_moon = [[db = require "lapis.db"
schema = require "lapis.db.schema"

{
  [%s]: =>
}
]]
local empty_moon = [[  [%s]: =>]]
local insert_end_lua
insert_end_lua = function(input, insertion)
  local P, S, Cc, Cs
  do
    local _obj_0 = require("lpeg")
    P, S, Cc, Cs = _obj_0.P, _obj_0.S, _obj_0.Cc, _obj_0.Cs
  end
  local whitespace = S(" \t\n\r")
  local file_tail = whitespace * P("}") * whitespace ^ 0 * P(-1)
  local pattern = Cs((1 - file_tail) ^ 0 * Cc(",\n" .. insertion) * file_tail)
  return pattern:match(input)
end
local insert_end_moon
insert_end_moon = function(input, insertion)
  local P, S, Cc, Cs
  do
    local _obj_0 = require("lpeg")
    P, S, Cc, Cs = _obj_0.P, _obj_0.S, _obj_0.Cc, _obj_0.Cs
  end
  local whitespace = S(" \t\n\r")
  local file_tail = P("}") * whitespace ^ 0 * P(-1)
  local pattern = (1 - file_tail) ^ 0 * Cc("\n" .. tostring(insertion) .. "\n") * file_tail
  local alt = P(1) ^ 0 * Cc("\n" .. tostring(insertion) .. "\n")
  return Cs(pattern + alt):match(input)
end
local get_next_name
get_next_name = function(counter_type, migrations_module)
  local _exp_0 = counter_type
  if "timestamp" == _exp_0 then
    return tostring(os.time())
  elseif "increment" == _exp_0 then
    if not (migrations_module) then
      return 1
    end
    local m = require(migrations_module)
    local k = 1
    while true do
      if not (m[k]) then
        return k
      end
      k = k + 1
    end
  end
end
local write
write = function(self, args)
  local output_language
  if args.lua then
    output_language = "lua"
  elseif args.moonscript then
    output_language = "moonscript"
  else
    output_language = self.default_language
  end
  local module_base_path = self:mod_to_path(args.migrations_module)
  local output_fname
  local _exp_0 = output_language
  if "lua" == _exp_0 then
    output_fname = tostring(module_base_path) .. ".lua"
  elseif "moonscript" == _exp_0 then
    output_fname = tostring(module_base_path) .. ".moon"
  end
  local have_file = self.command_runner.path.exists(output_fname)
  if have_file then
    local current_contents = assert(io.open(output_fname)):read("*a")
    local next_name = get_next_name(args.counter, args.migrations_module)
    local edited_contents
    local _exp_1 = output_language
    if "lua" == _exp_1 then
      edited_contents = insert_end_lua(current_contents, (empty_lua:format(next_name)))
    elseif "moonscript" == _exp_1 then
      edited_contents = insert_end_moon(current_contents, (empty_moon:format(next_name)))
    end
    assert(edited_contents, "Failed to edit the contents of the current migration file. Please ensure it's valid Lua/MoonScript code with a trailing } character")
    return self.command_runner.path.write_file(output_fname, edited_contents)
  else
    local next_name = get_next_name(args.counter)
    local _exp_1 = output_language
    if "lua" == _exp_1 then
      return self:write(output_fname, initial_lua:format(next_name))
    elseif "moonscript" == _exp_1 then
      return self:write(output_fname, initial_moon:format(next_name))
    end
  end
end
return {
  write = write,
  argparser = argparser
}
