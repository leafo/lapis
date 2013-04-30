
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

with_query_fn = (q, run using db) ->
  db = require "lapis.nginx.postgres"
  old = db._get_query_fn!
  db._set_query_fn q
  with run!
    db._set_query_fn old



{ :with_query_fn }
