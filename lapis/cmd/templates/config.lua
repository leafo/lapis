local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate config", "Generate a config module for lapis applications")
    _with_0:option("--config-module --module", "The module name of the migrations file"):default("config")
    _with_0:mutex(_with_0:flag("--cqueues", "Configured for cqueues/lua-http server"), _with_0:flag("--nginx", "Configured for nginx server"))
    _with_0:mutex(_with_0:flag("--lua", "Create a Lua module for config"), _with_0:flag("--moonscript --moon", "Create a MoonScript module for config"))
    return _with_0
  end
end
local initial_moon_nginx = [[import config from require "lapis.config"

config "development", ->
  server "nginx"
  code_cache "off"
  num_workers "1"
]]
local initial_lua_nginx = [[local config = require("lapis.config")

config("development", {
  server = "nginx",
  code_cache = "off",
  num_workers = "1"
})
]]
local initial_moon_cqueues = [[import config from require "lapis.config"

config "development", ->
  server "cqueues"
]]
local initial_lua_cqueues = [[local config = require("lapis.config")

config("development", {
  server = "cqueues"
})
]]
return {
  argparser = argparser,
  write = function(self, args)
    local output_language
    if args.lua then
      output_language = "lua"
    elseif args.moonscript then
      output_language = "moonscript"
    else
      output_language = self.default_language
    end
    local output_fname = self:mod_to_path(args.config_module, output_language)
    local output
    local _exp_0 = output_language
    if "lua" == _exp_0 then
      if args.nginx then
        output = initial_lua_nginx
      elseif args.cqueues then
        output = initial_lua_cqueues
      end
    elseif "moonscript" == _exp_0 then
      if args.nginx then
        output = initial_moon_nginx
      elseif args.cqueues then
        output = initial_moon_cqueues
      end
    else
      output = error("Unknown language: " .. tostring(output_language))
    end
    assert(output, "lapis generate requires a server to be selected to generate config, see lapis generate config --help")
    return self:write(output_fname, output)
  end
}
