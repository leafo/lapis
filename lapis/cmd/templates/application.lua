local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate application", "Generate an empty lapis application module")
    _with_0:option("--app-module --module", "The module name of the generated application"):default("app")
    _with_0:mutex(_with_0:flag("--lua", "Force output to be Lua"), _with_0:flag("--moonscript --moon", "Force output to be MoonScript"))
    return _with_0
  end
end
local initial_moon = [[lapis = require "lapis"

class extends lapis.Application
  "/": =>
    "Welcome to Lapis #{require "lapis.version"}!"
]]
local initial_lua = [[local lapis = require("lapis")
local app = lapis.Application()

app:get("/", function()
  return "Welcome to Lapis " .. require("lapis.version")
end)

return app
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
  local module_base_path = self:mod_to_path(args.app_module)
  local output_fname
  local _exp_0 = output_language
  if "lua" == _exp_0 then
    output_fname = tostring(module_base_path) .. ".lua"
  elseif "moonscript" == _exp_0 then
    output_fname = tostring(module_base_path) .. ".moon"
  end
  local _exp_1 = output_language
  if "lua" == _exp_1 then
    return self:write(output_fname, initial_lua)
  elseif "moonscript" == _exp_1 then
    return self:write(output_fname, initial_moon)
  end
end
return {
  write = write,
  argparser = argparser
}
