
argparser = ->
  with require("argparse") "lapis generate model", "Generates an empty model and places it in models_dir"
    \argument("model_name", "The name of the model (eg. users, posts, daily_views)")\convert (name) ->
      if name\match "%u"
        return nil, "model name should be underscore form, all lowercase.\nUse --class-name to set the generated class name"

      name

    \option("--class-name", "Override the generated class name. Defauls to camelize(model_name)")\argname "<name>"
    \option("--models-dir", "The directory where the model file is written")\argname("<dir>")\default "models"

    \mutex(
      \flag "--lua", "Force output to be Lua"
      \flag "--moonscript --moon", "Force output to be MoonScript"
    )

write = (args) =>
  class_name = if args.class_name
    args.class_name
  else
    import camelize from require "lapis.util"
    camelize args.model_name

  output_language = if args.lua
    "lua"
  elseif args.moonscript
    "moonscript"
  else
    @default_language

  output_name = "#{args.models_dir}/#{args.model_name}"

  switch output_language
    when "lua"
      @write "#{output_name}.lua", [[
local Model = require("lapis.db.model").Model
local ]] .. class_name .. [[, ]] .. class_name .. [[_mt = Model:extend("]] .. args.model_name ..[[")

return ]] .. class_name .. [[
]]
    when "moonscript"
      @write "#{output_name}.moon", [[
db = require "lapis.db"
import Model from require "lapis.db.model"

class ]] .. class_name .. [[ extends Model
]]

{:write, :argparser}

