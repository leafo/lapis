return {
  write = function(self, args)
    local output_language
    if args.lua then
      output_language = "lua"
    elseif args.moonscript then
      output_language = "moonscript"
    else
      output_language = self.default_language
    end
    local extension
    local _exp_0 = output_language
    if "lua" == _exp_0 then
      extension = "lua"
    elseif "moonscript" == _exp_0 then
      extension = "moon"
    end
    local output_file = "config." .. tostring(extension)
    local output
    local _exp_1 = output_language
    if "lua" == _exp_1 then
      local _exp_2 = args.server
      if "nginx" == _exp_2 then
        output = [[local config = require("lapis.config")

config("development", {
  server = "nginx",
  code_cache = "off",
  num_workers = "1"
})
]]
      elseif "cqueues" == _exp_2 then
        output = [[local config = require("lapis.config")

config("development", {
  server = "cqueues"
})
]]
      end
    elseif "moonscript" == _exp_1 then
      local _exp_2 = args.server
      if "nginx" == _exp_2 then
        output = [[import config from require "lapis.config"

config "development", ->
  server "nginx"
  code_cache "off"
  num_workers "1"
]]
      elseif "cqueues" == _exp_2 then
        output = [[import config from require "lapis.config"

config "development", ->
  server "cqueues"
  code_cache "off"
  num_workers "1"
]]
      end
    end
    return self:write(output_file, output)
  end
}
