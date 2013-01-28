
db = require "lapis.db"

types = setmetatable {
  serial: "serial NOT NULL"
  varchar: "character varying(255) NOT NULL"
  varchar_nullable: "character varying(255)"
  text: "text NOT NULL"
  text_nullable: "text"
  time: "timestamp without time zone NOT NULL"
  time_nullable: "timestamp without time zone NOT NULL"
  integer: "integer NOT NULL DEFAULT 0"
  foreign_key: "integer NOT NULL"
  boolean: "boolean NOT NULL DEFAULT FALSE"
}, __index: (key) =>
  error "Don't know column type `#{key}`"

import concat from table
append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

extract_options = (cols) ->
  options = {}
  cols = for col in *cols
    if type(col) == "table"
      for k,v in pairs col
        options[k] = v
      continue
    col

  cols, options

entity_exists = (name) ->
  name = db.escape_literal name
  res = unpack db.select "COUNT(*) as c from pg_class where relname = #{name}"
  res.c > 0

create_table = (name, columns) ->
  buffer = {"CREATE TABLE IF NOT EXISTS #{db.escape_identifier name} ("}
  add = (...) -> append_all buffer, ...

  for i, c in ipairs columns
    add "\n  "
    if type(c) == "table"
      name, kind = unpack c
      add db.escape_identifier(name), " ", kind
    else
      add c

    add "," unless i == #columns

  add "\n" if #columns > 0

  add ");"
  db.query concat buffer

create_index = (tname, ...) ->
  parts = [p for p in *{tname, ...} when type(p) == "string"]
  index_name = concat(parts, "_") .. "_idx"
  return if entity_exists index_name

  columns, options = extract_options {...}

  buffer = {"CREATE"}
  append_all buffer, " UNIQUE" if options.unique
  append_all buffer, " INDEX ON #{db.escape_identifier tname} ("

  for i, col in ipairs columns
    append_all buffer, col
    append_all buffer, ", " unless i == #columns

  append_all buffer, ");"
  db.query concat buffer

drop_table = (tname) ->
  db.query "DROP TABLE IF EXISTS #{db.escape_identifier tname};"

add_column = (tname, col_name, col_type) ->
  tname = db.escape_identifier tname
  col_name = db.escape_identifier col_name
  db.query "ALTER TABLE #{tname} ADD COLUMN #{col_name} #{col_type}"

drop_column = (tname, col_name) ->
  tname = db.escape_identifier tname
  col_name = db.escape_identifier col_name
  db.query "ALTER TABLE #{tname} DROP COLUMN #{col_name}"

rename_column = (tname, col_from, col_to) ->
  tname = db.escape_identifier tname
  col_from = db.escape_identifier col_from
  col_to = db.escape_identifier col_to
  db.query "ALTER TABLE #{tname} RENAME COLUMN #{col_from} TO #{col_to}"

rename_table = (tname_from, tname_to) ->
  tname_from = db.escape_identifier tname_from
  tname_to = db.escape_identifier tname_to
  db.query "ALTER TABLE #{tname_from} RENAME TO #{tname_to}"

if ... == "test"
  db.query = print
  db.select = -> { { c: 0 } }

  add_column "hello", "dads", types.integer
  rename_column "hello", "dads", "cats"
  drop_column "hello", "cats"
  rename_table "hello", "world"

{
  :types, :create_table, :drop_table, :create_index, :add_column, :drop_column
  :rename_column, :rename_table
}

