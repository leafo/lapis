
argparser = ->
  with require("argparse") "lapis generate spec", "Generates an empty Busted test file"
    \argument("spec_name", "The name of the spec in lowercase")\convert (name) ->
      if name\match "%u"
        return nil, "spec name should be underscore form, all lowercase"

      name

    \option("--spec-dir", "Where tests are located")\argname("<dir>")\default "spec"
    \option("--type", "Template type to use. Default to autodetect based on spec_name")\choices {
      "models"
      "applications"
      "helpers"
    }

    \mutex(
      \flag "--lua", "Force output to be Lua"
      \flag "--moonscript --moon", "Force output to be MoonScript"
    )

SPEC_TYPES = {
  models: {
    lua: (name) ->
      model_name = name\match "[^.]+$"
      import camelize from require "lapis.util"
      model_class_name = camelize model_name

      [[
local truncate_tables = reuqire("lapis.spec.db").truncate_tables

describe("]] .. name .. [[", function()
  local ]] .. model_class_name .. [[ = require("models").]] .. model_class_name .. [[


  before_each(function()
    truncate_tables(]] .. model_class_name .. [[)
  end)

  it("should ...", function()
  end)
end)
]]
    moonscript: (name) ->
      model_name = name\match "[^.]+$"
      import camelize from require "lapis.util"
      model_class_name = camelize model_name

      [[
import truncate_tables from require "lapis.spec.db"
import ]] .. model_class_name .. [[ from require "models"

describe "]] ..name .. [[", ->
  before_each ->
    truncate_tables ]] .. model_class_name .. [[



  it "should ...", ->
]]
  }

  default: {
    lua: (name) ->
      [[
describe("]] .. name .. [[", function()
  it("should ...", function()
  end)
end)
]]

    moonscript: (name) ->
      [[
describe "]] ..name .. [[", ->
  it "should ...", ->
]]
  }

  applications: {
    lua: (name) ->
      [[
local use_test_server = require("lapis.spec").use_test_server
local request = require("lapis.spec.server").request
local truncate_tables = require("lapis.spec.db").truncate_tables

describe("]] .. name .. [[", function()
  use_test_server()

  before_each(function()
  end)

  it("should ...", function()
  end)
end)
]]

    moonscript: (name) ->
      [[
import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

describe "]] ..name .. [[", ->
  use_test_server!

  before_each ->

  it "should ...", ->
]]
  }
}

write = (args) =>
  output_language = if args.lua
    "lua"
  elseif args.moonscript
    "moonscript"
  else
    @default_language

  extension = switch output_language
    when "lua"
      "lua"
    when "moonscript"
      "moon"

  output_file = "#{args.spec_dir}/#{@mod_to_path args.spec_name}_spec.#{extension}"
  prefix = args.spec_name\match "^(.+)%."

  output_type = if args.type
    SPEC_TYPES[args.type]
  else
    SPEC_TYPES[prefix] or SPEC_TYPES.default

  assert output_type, "Failed to find output type for spec"

  @write output_file, output_type[output_language] args.spec_name

{:argparser, :write}

