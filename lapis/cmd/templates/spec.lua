local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate spec", "Generates an empty Busted test file")
    _with_0:argument("spec_name", "The name of the spec in lowercase"):convert(function(name)
      if name:match("%u") then
        return nil, "spec name should be underscore form, all lowercase"
      end
      return name
    end)
    _with_0:option("--spec-dir", "Where tests are located"):argname("<dir>"):default("spec")
    _with_0:option("--type", "Template type to use. Default to autodetect based on spec_name"):choices({
      "models",
      "applications",
      "helpers"
    })
    _with_0:mutex(_with_0:flag("--lua", "Force output to be Lua"), _with_0:flag("--moonscript --moon", "Force output to be MoonScript"))
    return _with_0
  end
end
local SPEC_TYPES = {
  models = {
    lua = function(name)
      local model_name = name:match("[^.]+$")
      local camelize
      camelize = require("lapis.util").camelize
      local model_class_name = camelize(model_name)
      return [[local truncate_tables = reuqire("lapis.spec.db").truncate_tables

describe("]] .. name .. [[", function()
  local ]] .. model_class_name .. [[ = require("models").]] .. model_class_name .. [[

  before_each(function()
    truncate_tables(]] .. model_class_name .. [[)
  end)

  it("should ...", function()
  end)
end)
]]
    end,
    moonscript = function(name)
      local model_name = name:match("[^.]+$")
      local camelize
      camelize = require("lapis.util").camelize
      local model_class_name = camelize(model_name)
      return [[import truncate_tables from require "lapis.spec.db"
import ]] .. model_class_name .. [[ from require "models"

describe "]] .. name .. [[", ->
  before_each ->
    truncate_tables ]] .. model_class_name .. [[


  it "should ...", ->
]]
    end
  },
  default = {
    lua = function(name)
      return [[describe("]] .. name .. [[", function()
  it("should ...", function()
  end)
end)
]]
    end,
    moonscript = function(name)
      return [[describe "]] .. name .. [[", ->
  it "should ...", ->
]]
    end
  },
  applications = {
    lua = function(name)
      return [[local use_test_server = require("lapis.spec").use_test_server
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
    end,
    moonscript = function(name)
      return [[import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

describe "]] .. name .. [[", ->
  use_test_server!

  before_each ->

  it "should ...", ->
]]
    end
  }
}
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
  local extension
  local _exp_0 = output_language
  if "lua" == _exp_0 then
    extension = "lua"
  elseif "moonscript" == _exp_0 then
    extension = "moon"
  end
  local output_file = tostring(args.spec_dir) .. "/" .. tostring(self:mod_to_path(args.spec_name)) .. "_spec." .. tostring(extension)
  local prefix = args.spec_name:match("^(.+)%.")
  local output_type
  if args.type then
    output_type = SPEC_TYPES[args.type]
  else
    output_type = SPEC_TYPES[prefix] or SPEC_TYPES.default
  end
  assert(output_type, "Failed to find output type for spec")
  return self:write(output_file, output_type[output_language](args.spec_name))
end
return {
  argparser = argparser,
  write = write
}
