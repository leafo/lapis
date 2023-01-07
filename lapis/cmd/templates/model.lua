local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate model", "Generates an empty model and places it in models_dir")
    _with_0:argument("model_name", "The name of the model (eg. users, posts, daily_views)"):convert(function(name)
      if name:match("%u") then
        return nil, "model name should be underscore form, all lowercase.\nUse --class-name to set the generated class name"
      end
      return name
    end)
    _with_0:option("--class-name", "Override the generated class name. Defauls to camelize(model_name)"):argname("<name>")
    _with_0:option("--models-dir", "The directory where the model file is written"):argname("<dir>"):default("models")
    _with_0:mutex(_with_0:flag("--lua", "Force output to be Lua"), _with_0:flag("--moonscript --moon", "Force output to be MoonScript"))
    return _with_0
  end
end
local write
write = function(self, args)
  local class_name
  if args.class_name then
    class_name = args.class_name
  else
    local camelize
    camelize = require("lapis.util").camelize
    class_name = camelize(args.model_name)
  end
  local output_language
  if args.lua then
    output_language = "lua"
  elseif args.moonscript then
    output_language = "moonscript"
  else
    output_language = self.default_language
  end
  local output_name = tostring(args.models_dir) .. "/" .. tostring(args.model_name)
  local _exp_0 = output_language
  if "lua" == _exp_0 then
    return self:write(tostring(output_name) .. ".lua", [[local Model = require("lapis.db.model").Model
local ]] .. class_name .. [[, ]] .. class_name .. [[_mt = Model:extend("]] .. args.model_name .. [[")

return ]] .. class_name .. [[]])
  elseif "moonscript" == _exp_0 then
    return self:write(tostring(output_name) .. ".moon", [[db = require "lapis.db"
import Model from require "lapis.db.model"

class ]] .. class_name .. [[ extends Model
]])
  end
end
return {
  write = write,
  argparser = argparser
}
