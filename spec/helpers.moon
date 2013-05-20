
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
  with run!
    db.set_backend "raw", old_query

{ :with_query_fn }
