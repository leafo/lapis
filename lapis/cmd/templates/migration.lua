local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate migration", "Create a slot for a new empty migration, or generate a new one")
    _with_0:option("--counter", "Naming convention for new migration"):choices({
      "timestamp"
    }):default("timestamp")
    _with_0:option("--migrations-module", "The module name of the migrations file"):default("migrations")
    _with_0:mutex(_with_0:flag("--lua", "Force editing/creating Lua file"), _with_0:flag("--moonscript --moon", "Force editing/creating MoonScript file"))
    return _with_0
  end
end
local empty_lua = [[local db = reuqire("lapis.db")
local schema = require("lapis.db.schema")

return {
  [%s]: function()
  end
}
]]
local empty_moon = [[db = require "lapis.db"
schema = require "lapis.db.schema"

{
  [%s]: =>
}
]]
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
    return error("TODO: have migrations file: " .. tostring(output_fname) .. ", edit me")
  else
    local next_name
    local _exp_1 = args.counter
    if "timestamp" == _exp_1 then
      next_name = tostring(os.time())
    else
      next_name = error("Don't know how to get next name")
    end
    local _exp_2 = output_language
    if "lua" == _exp_2 then
      return self:write(output_fname, empty_lua:format(next_name))
    elseif "moonscript" == _exp_2 then
      return self:write(output_fname, empty_moon:format(next_name))
    end
  end
end
return {
  write = write,
  argparser = argparser
}
