db = require "lapis.db.postgres"

import gen_index_name from require "lapis.db.base"
import escape_literal, escape_identifier from db
import concat from table

append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

extract_options = (cols) ->
  options = {}
  cols = for col in *cols
    if type(col) == "table" and col[1] != "raw"
      for k,v in pairs col
        options[k] = v
      continue
    col

  cols, options

entity_exists = (name) ->
  name = escape_literal name
  res = unpack db.select "COUNT(*) as c from pg_class where relname = #{name}"
  res.c > 0

create_table = (name, columns) ->
  buffer = {"CREATE TABLE IF NOT EXISTS #{escape_identifier name} ("}
  add = (...) -> append_all buffer, ...

  for i, c in ipairs columns
    add "\n  "
    if type(c) == "table"
      name, kind = unpack c
      add escape_identifier(name), " ", tostring kind
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

  append_all buffer, " INDEX ",
    escape_identifier(index_name),
    " ON ", escape_identifier tname

  if options.method
    append_all buffer, " USING ", options.method
    
  append_all buffer, " ("

  for i, col in ipairs columns
    append_all buffer, escape_identifier(col)
    append_all buffer, ", " unless i == #columns

  append_all buffer, ")"

  if options.tablespace
    append_all buffer, " TABLESPACE ", options.tablespace
    
  if options.where
    append_all buffer, " WHERE ", options.where

  append_all buffer, ";"
  db.query concat buffer

drop_index = (...) ->
  index_name = gen_index_name ...
  db.query "DROP INDEX IF EXISTS #{escape_identifier index_name}"

drop_table = (tname) ->
  db.query "DROP TABLE IF EXISTS #{escape_identifier tname};"

add_column = (tname, col_name, col_type) ->
  tname = escape_identifier tname
  col_name = escape_identifier col_name
  db.query "ALTER TABLE #{tname} ADD COLUMN #{col_name} #{col_type}"

drop_column = (tname, col_name) ->
  tname = escape_identifier tname
  col_name = escape_identifier col_name
  db.query "ALTER TABLE #{tname} DROP COLUMN #{col_name}"

rename_column = (tname, col_from, col_to) ->
  tname = escape_identifier tname
  col_from = escape_identifier col_from
  col_to = escape_identifier col_to
  db.query "ALTER TABLE #{tname} RENAME COLUMN #{col_from} TO #{col_to}"

rename_table = (tname_from, tname_to) ->
  tname_from = escape_identifier tname_from
  tname_to = escape_identifier tname_to
  db.query "ALTER TABLE #{tname_from} RENAME TO #{tname_to}"

class ColumnType
  default_options: { null: false }

  new: (@base, @default_options) =>

  __call: (opts) =>
    out = @base

    for k,v in pairs @default_options
      opts[k] = v unless opts[k] != nil

    unless opts.null
      out ..= " NOT NULL"

    if opts.default != nil
      out ..= " DEFAULT " .. escape_literal opts.default

    if opts.unique
      out ..= " UNIQUE"

    if opts.primary_key
      out ..= " PRIMARY KEY"

    out

  __tostring: => @__call @default_options


class TimeType extends ColumnType
  __tostring: ColumnType.__tostring

  __call: (opts) =>
    base = @base
    @base = base .. " with time zone" if opts.timezone

    with ColumnType.__call @, opts
      @base = base


C = ColumnType
T = TimeType
types = setmetatable {
  serial:       C "serial"
  varchar:      C "character varying(255)"
  text:         C "text"
  time:         T "timestamp"
  date:         C "date"
  integer:      C "integer", null: false, default: 0
  numeric:      C "numeric", null: false, default: 0
  real:         C "real", null: false, default: 0
  double:       C "double precision", null: false, default: 0
  boolean:      C "boolean", null: false, default: false
  foreign_key:  C "integer"
}, __index: (key) =>
  error "Don't know column type `#{key}`"

{
  :types, :create_table, :drop_table, :create_index, :drop_index, :add_column,
  :drop_column, :rename_column, :rename_table, :entity_exists, :gen_index_name
}

