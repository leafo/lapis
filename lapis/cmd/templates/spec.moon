
check_args = (name) ->
  error "spec template takes arguments: name" unless name

content = (name) ->
  [[import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"
import truncate_tables from require "lapis.spec.db"

describe "]] ..name .. [[", ->
  use_test_server!

  before_each ->

  it "should do something", ->
]]

filename = (name) ->
  "spec/#{name}_spec.moon"


{:content, :filename, :check_args}

