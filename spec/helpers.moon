
one_of = (state, arguments) ->
  { input, expected } = arguments

  for e in *expected
    return true if input == e

  false

s = require "say"

s\set "assertion.one_of.positive",
  "Expected %s to be one of:\n%s"

s\set "assertion.one_of.negative",
  "Expected property %s to not be in:\n%s"

assert\register "assertion",
  "one_of", one_of, "assertion.one_of.positive", "assertion.one_of.negative"

with_query_fn = (q, run) ->
  db = require "lapis.nginx.postgres"
  old_query = db.set_backend "raw", q
  if not run
    -> db.set_backend "raw", old_query
  else
    with run!
      db.set_backend "raw", old_query

assert_queries = (expected, result) ->
  assert #expected == #result, "number of expected queries does not match number received"
  for i, q in ipairs expected
    if type(q) == "table"
      assert.one_of result[i], q
    else
      assert.same q, result[i]

{ :with_query_fn, :assert_queries }
