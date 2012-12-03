
-- This is a simple interface form making queries to postgres on top of
-- ngx_postgres
--
-- Add the following upstream to your http:
--
-- upstream database {
--   postgres_server  127.0.0.1 dbname=... user=... password=...;
-- }
--
-- Add the following location to your server:
--
-- location /query {
--   postgres_pass database;
--   postgres_query $echo_request_body;
-- }
--

parser = require "rds.parser"

import concat from table

logger = nil

proxy_location = "/query"
set_proxy_location = (loc) -> proxy_location = loc

set_logger = (l) -> logger = l

NULL = {}
raw = (val) -> {"raw", tostring(val)}

TRUE = raw"TRUE"
FALSE = raw"FALSE"

format_date = (time) ->
  os.date "!%Y-%m-%d %H:%M:%S", time

append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

escape_identifier = (ident) ->
  ident = tostring ident
  '"' ..  (ident\gsub '"', '""') .. '"'

escape_literal = (val) ->
  switch type val
    when "number"
      return tostring val
    when "string"
      return "'#{(val\gsub "'", "''")}'"
    when "boolean"
      return val and "TRUE" or "FALSE"
    when "table"
      return "NULL" if val == NULL
      if val[1] == "raw" and val[2]
        return val[2]

  error "don't know how to escape value: #{val}"

-- replace ? with values
interpolate_query = (query, ...) ->
  values = {...}
  i = 0
  (query\gsub "%?", ->
    i += 1
    escape_literal values[i])

-- (col1, col2, col3) VALUES (val1, val2, val3)
encode_values = (t, buffer) ->
  have_buffer = buffer
  buffer or= {}

  tuples = [{k,v} for k,v in pairs t]
  cols = concat [escape_identifier pair[1] for pair in *tuples], ", "
  vals = concat [escape_literal pair[2] for pair in *tuples], ", "

  append_all buffer, "(", cols, ") VALUES (", vals, ")"
  concat buffer unless have_buffer

-- col1 = val1, col2 = val2, col3 = val3
encode_assigns = (t, buffer, join=", ") ->
  have_buffer = buffer
  buffer or= {}

  for k,v in pairs t
    append_all buffer, escape_identifier(k), " = ", escape_literal(v), join
  buffer[#buffer] = nil

  concat buffer unless have_buffer

raw_query = (str) ->
  logger.query str if logger
  res, m = ngx.location.capture proxy_location, {
    body: str
  }
  parser.parse res.body

query = (str, ...) ->
  if select("#", ...) > 0
    str = interpolate_query str, ...
  raw_query str

_select = (str, ...) ->
  res, err = query "SELECT " .. str, ...
  if res
    res.resultset
  else
    nil, err

_insert = (tbl, values, ...) ->
  if values._timestamp
    values._timestamp = nil
    time = format_date!

    values.created_at = time
    values.updated_at = time

  buff = {
    "INSERT INTO "
    escape_identifier(tbl)
    " "
  }
  encode_values values, buff

  returning = {...}
  if next returning
    append_all buff, " RETURNING "
    for i, r in ipairs returning
      append_all buff, escape_identifier r
      append_all buff, ", " if i != #returning

  raw_query concat buff

add_cond = (buffer, cond, ...) ->
  append_all buffer, " WHERE "
  switch type cond
    when "table"
      encode_assigns cond, buffer
    when "string"
      append_all buffer, interpolate_query cond, ...

_update = (table, values, cond, ...) ->
  buff = {
    "UPDATE "
    escape_identifier(table)
    " SET "
  }

  encode_assigns values, buff

  if cond
    add_cond buff, cond, ...

  raw_query concat buff

_delete = (table, cond, ...) ->
  buff = {
    "DELETE FROM "
    escape_identifier(table)
  }

  if cond
    add_cond buff, cond, ...

  raw_query concat buff

if ... == "test"
  raw_query = (str) -> print "QUERY:", str

  print escape_identifier 'dad'
  print escape_identifier 'select'
  print escape_identifier 'love"fish'
  print
  print escape_literal 3434
  print escape_literal "cat's soft fur"
  print
  print interpolate_query "select * from cool where hello = ?", "world"
  print interpolate_query "update x set x = ?", raw"y + 1"
  print

  v = { hello: "world", age: 34 }

  print encode_values v
  print encode_assigns v

  print

  _select "* from things where id = ?", "cool days"
  _insert "cats", age: 123, name: "catter"

  _update "cats", { age: raw"age - 10" }, "name = ?", "catter"
  _update "cats", { age: raw"age - 10" }, { name: NULL }

  _delete "cats"
  _delete "cats", "name = ?", "rump"
  _delete "cats", name: "rump"


  _insert "cats", { age: 123, name: "catter" }, "age"
  _insert "cats", { age: 123, name: "catter" }, "age", "name"

  _insert "cats", { hungry: true }

  -- query "update things set #{encode_assigns(v)} where id = ?", "hello-world"

{
  :query, :raw, :NULL, :TRUE, :FALSE, :escape_literal, :escape_identifier
  :encode_values, :encode_assigns, :interpolate_query
  :set_proxy_location
  :set_logger

  select: _select
  insert: _insert
  update: _update
  delete: _delete
}
