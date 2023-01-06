local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate flow", "Generates an empty flow and places it in flows_dir")
    _with_0:argument("flow_name", "The name of the flow in lowercase (eg. edit_post, users.profile)"):convert(function(name)
      if name:match("%u") then
        return nil, "flow name should be underscore form, all lowercase.\nUse --class-name to set the generated class name"
      end
      return name
    end)
    _with_0:option("--class-name", "Override the generated class name. Defauls to {camelize(flow_name)}Flow"):argname("<name>")
    _with_0:option("--flows-dir", "The directory where the flow file is written"):argname("<dir>"):default("flows")
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
    local tail_name = args.flow_name:match("[^.]+$") or args.flow_name
    class_name = tostring(camelize(tail_name)) .. "Flow"
  end
  local output_language
  if args.lua then
    output_language = "lua"
  elseif args.moonscript then
    output_language = "moonscript"
  else
    output_language = self.default_language
  end
  local output_name = tostring(args.flows_dir) .. "/" .. tostring(self:mod_to_path(args.flow_name))
  local _exp_0 = output_language
  if "lua" == _exp_0 then
    return self:write(tostring(output_name) .. ".lua", [[local Flow = require("lapis.flow").Flow

local ]] .. class_name .. [[, ]] .. class_name .. [[_mt = Flow:extend("]] .. class_name .. [[")

return ]] .. class_name .. [[]])
  elseif "moonscript" == _exp_0 then
    return self:write(tostring(output_name) .. ".moon", [[import Flow from require "lapis.flow"

class ]] .. class_name .. [[ extends Flow
]])
  end
end
return {
  write = write,
  argparser = argparser
}
