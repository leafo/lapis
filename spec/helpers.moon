util = require 'luassert.util'

pairs = _G.pairs

one_of = (state, arguments) ->
  { input, expected } = arguments

  input_is_table = type(input) == "table"

  for e in *expected
    if input_is_table and type(e) == "table"
      if util.deepcompare input, e, true
        return true
    else
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

is_string_array = (list) ->
  return false unless type(list) == "table"

  for k,v in pairs list
    if type(k) != "number"
      return false

    if type(v) != "string"
      return false

  return true

assert_queries = (expected, result, opts) ->
  -- short circuit for better error messsage
  if not opts and is_string_array expected
    return assert.same expected, result

  if #expected != #result
    error "number of expected queries (#{#expected}) does not match number received (#{#result})"

  if opts and opts.sorted
    e = [q for q in *expected]
    r = [q for q in *result]

    table.sort e
    table.sort r

    assert.same e, r
    return

  for i, q in ipairs expected
    if type(q) == "table"
      assert.one_of result[i], q
    else
      assert.same q, result[i]

stub_queries = ->
  import setup, teardown, before_each from require "busted"
  local queries, query_mock

  get_queries = -> queries
  set_queries = (q) -> queries = q

  mock_query = (pattern, result) ->
    -- insert on the front to take precedence
    table.insert query_mock, 1, {pattern, result}

  show_queries = os.getenv("LAPIS_SHOW_QUERIES")

  local restore
  setup ->
    _G.ngx = { null: nil }
    restore = with_query_fn (q) ->
      if show_queries
        require("lapis.logging").query q

      table.insert queries, (q\gsub("%s+", " ")\gsub("[\n\t]", " "))

      -- try to find a mock with pattern that matches query
      for {pattern, result} in *query_mock
        if q\match pattern
          return if type(result) == "function"
            result q
          else
            result

      {}

  teardown ->
    _G.ngx = nil
    restore!

  before_each ->
    queries = {}
    query_mock = {}

  get_queries, mock_query, set_queries

-- note: we can't do stub(_G, "pairs") because of a limitation of busted
sorted_pairs = (sort=table.sort) ->
  import before_each, after_each from require "busted"
  local _pairs
  before_each ->
    _pairs = _G.pairs
    _G.pairs = (object, ...) ->
      keys = [k for k in _pairs object]
      sort keys, (a,b) ->
        if type(a) == type(b)
          tostring(a) < tostring(b)
        else
          type(a) < type(b)

      idx = 0

      ->
        idx += 1
        key = keys[idx]
        if key != nil
          key, object[key]

  after_each ->
    _G.pairs = _pairs

{ :with_query_fn, :assert_queries, :stub_queries, :sorted_pairs }
