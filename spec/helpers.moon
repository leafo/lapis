
one_of = (state, arguments) ->
  { input, expected } = arguments

  for e in *expected
    return true if input == e

  false

s = require "say"
assert = require "luassert"

s\set "assertion.one_of.positive",
  "Expected %s to be one of:\n%s"

s\set "assertion.one_of.negative",
  "Expected property %s to not be in:\n%s"

assert\register "assertion",
  "one_of", one_of, "assertion.one_of.positive", "assertion.one_of.negative"

with_query_fn = (q, run, db=require "lapis.db.postgres") ->
  old_query = db.get_raw_query!
  db.set_raw_query q
  if not run
    -> db.set_raw_query old_query
  else
    with run!
      db.set_raw_query old_query

assert_queries = (expected, result) ->
  assert #expected == #result, "number of expected queries does not match number received"
  for i, q in ipairs expected
    if type(q) == "table"
      assert.one_of result[i], q
    else
      assert.same q, result[i]

stub_queries = ->
  import setup, teardown, before_each from require "busted"
  local queries, query_mock

  get_queries = -> queries

  mock_query = (pattern, result) ->
    query_mock[pattern] = result

  local restore
  setup ->
    _G.ngx = { null: nil }
    restore = with_query_fn (q) ->
      table.insert queries, (q\gsub("%s+", " ")\gsub("[\n\t]", " "))

      -- try to find a mock
      for k,v in pairs query_mock
        if q\match k
          return if type(v) == "function"
            v!
          else
            v

      {}

  teardown ->
    _G.ngx = nil
    restore!

  before_each ->
    queries = {}
    query_mock = {}

  get_queries, mock_query

{ :with_query_fn, :assert_queries, :stub_queries }
