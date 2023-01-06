argparser = ->
  with require("argparse") "lapis generate flow", "Generates an empty flow and places it in flows_dir"
    \argument("flow_name", "The name of the flow in lowercase (eg. edit_post, users.profile)")\convert (name) ->
      if name\match "%u"
        return nil, "flow name should be underscore form, all lowercase.\nUse --class-name to set the generated class name"

      name

    \option("--class-name", "Override the generated class name. Defauls to {camelize(flow_name)}Flow")\argname "<name>"
    \option("--flows-dir", "The directory where the flow file is written")\argname("<dir>")\default "flows"

    \mutex(
      \flag "--lua", "Force output to be Lua"
      \flag "--moonscript --moon", "Force output to be MoonScript"
    )

write = (args) =>
  class_name = if args.class_name
    args.class_name
  else
    import camelize from require "lapis.util"
    tail_name = args.flow_name\match("[^.]+$") or args.flow_name
    "#{camelize tail_name}Flow"

  output_language = if args.lua
    "lua"
  elseif args.moonscript
    "moonscript"
  else
    @default_language

  output_name = "#{args.flows_dir}/#{@mod_to_path args.flow_name}"

  switch output_language
    when "lua"
      @write "#{output_name}.lua", [[
local Flow = require("lapis.flow").Flow

local ]] .. class_name .. [[, ]] .. class_name .. [[_mt = Flow:extend("]] .. class_name .. [[")

return ]] .. class_name .. [[
]]
    when "moonscript"
      @write "#{output_name}.moon", [[
import Flow from require "lapis.flow"

class ]].. class_name .. [[ extends Flow
]]

{:write, :argparser}


