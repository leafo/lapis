
check_args = (name, more) ->
  error "spec template takes arguments: name" unless name

  if name\match "%u"
    error "name should be underscore form, all lowercase"

  if more
    error "got a second argument to generator, did you mean to pass a string?"

filename = (name) ->
  "spec/#{name}_spec.moon"


spec_types = {
  models: (name) ->
    [[import use_test_env from require "lapis.spec"
import truncate_tables from require "lapis.spec.db"

describe "]] ..name .. [[", ->
  use_test_env!

  before_each ->

  it "should ...", ->
]]

  applications: (name) ->
    [[import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

describe "]] ..name .. [[", ->
  use_test_server!

  before_each ->

  it "should ...", ->
]]
}

spec_types.helpers = spec_types.models

write = (writer, name) ->
  path = writer\mod_to_path name
  prefix = name\match "^(.+)%."
  writer\write filename(path), (spec_types[prefix] or spec_types.applications) name

{:check_args, :write}

