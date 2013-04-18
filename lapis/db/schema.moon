
db = require "lapis.db"

import escape_literal from db

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

gen_index_name = (...) ->
  parts = [p for p in *{...} when type(p) == "string"]
  concat(parts, "_") .. "_idx"

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
  index_name = gen_index_name tname, ...
  return if entity_exists index_name

  columns, options = extract_options {...}

  buffer = {"CREATE"}
  append_all buffer, " UNIQUE" if options.unique
  append_all buffer, " INDEX ON #{db.escape_identifier tname} ("

  for i, col in ipairs columns
    append_all buffer, col
    append_all buffer, ", " unless i == #columns

  append_all buffer, ")"

  if options.where
    append_all buffer, " WHERE ", options.where

  append_all buffer, ";"
  db.query concat buffer

drop_index = (...) ->
  index_name = gen_index_name ...
  db.query "DROP INDEX IF EXISTS #{db.escape_identifier index_name}"

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

class ColumnType
  default_options: { nullable: false }

  new: (@base, @default_options) =>

  __call: (opts) =>
    out = @base

    unless opts.nullable
      out ..= " NOT NULL"

    if default = opts.default
      out ..= " DEFAULT " .. escape_literal default

    if opts.unique
      out ..= " UNIQUE"

    if opts.primary_key
      out ..= " PRIMARY KEY"

    out

  __tostring: => @__call @default_options

C = ColumnType
types = setmetatable {
  serial:       C "serial"
  varchar:      C "character varying(255)"
  text:         C "text"
  time:         C "timestamp without time zone"
  date:         C "date"
  integer:      C "integer", nullable: false, default: 0
  numeric:      C "numeric", nullable: false, default: 0
  boolean:      C "boolean", nullable: false, default: false
  foreign_key:  C "integer"
}, __index: (key) =>
  error "Don't know column type `#{key}`"

if ... == "test"
  db.query = print
  db.select = -> { { c: 0 } }

  add_column "hello", "dads", types.integer
  rename_column "hello", "dads", "cats"
  drop_column "hello", "cats"
  rename_table "hello", "world"

  print types.integer
  print types.integer nullable: true
  print types.integer nullable: true, default: 100, unique: true
  print types.serial

{
  :types, :create_table, :drop_table, :create_index, :drop_index, :add_column,
  :drop_column, :rename_column, :rename_table
}

