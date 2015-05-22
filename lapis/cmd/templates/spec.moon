
check_args = (name, more) ->
  error "spec template takes arguments: name" unless name

  if name\match "%u"
    error "name should be underscore form, all lowercase"

  if more
    error "got a second argument to generator, did you mean to pass a string?"

filename = (name) ->
  "spec/#{name}_spec.moon"

write = (writer, name) ->
  writer\write filename(name), [[import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

describe "]] ..name .. [[", ->
  use_test_server!

  before_each ->

  it "should do something", ->
]]


{:check_args, :write}

