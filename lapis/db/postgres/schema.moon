db = require "lapis.db.postgres"

import gen_index_name from require "lapis.db.base"
import escape_literal, escape_identifier, is_raw from db
import concat from table
unpack = unpack or table.unpack

append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

extract_options = (cols) ->
  options = {}
  cols = for col in *cols
    if type(col) == "table" and not is_raw(col)
      for k,v in pairs col
        options[k] = v
      continue
    col

  cols, options

entity_exists = (name) ->
  name = escape_literal name
  res = unpack db.select "COUNT(*) as c from pg_class where relname = #{name}"
  res.c > 0

create_table = (name, columns, opts={}) ->
  prefix = if opts.if_not_exists
    "CREATE TABLE IF NOT EXISTS "
  else
    "CREATE TABLE "

  buffer = {prefix, escape_identifier(name), " ("}
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

  add ")"
  db.query concat buffer

create_index = (tname, ...) ->
  index_name = gen_index_name tname, ...
  columns, options = extract_options {...}

  prefix = if options.unique
    "CREATE UNIQUE INDEX "
  else
    "CREATE INDEX "

  buffer = {prefix}

  append_all buffer, "CONCURRENTLY " if options.concurrently
  append_all buffer, "IF NOT EXISTS " if options.if_not_exists

  append_all buffer, escape_identifier(index_name),
    " ON ", escape_identifier tname

  if options.method
    append_all buffer, " USING ", options.method
    
  append_all buffer, " ("

  for i, col in ipairs columns
    append_all buffer, escape_identifier col
    append_all buffer, ", " unless i == #columns

  append_all buffer, ")"

  if options.tablespace
    append_all buffer, " TABLESPACE ", escape_identifier options.tablespace
    
  if options.where
    append_all buffer, " WHERE ", options.where

  if options.when
    error "did you mean create_index `where`?"

  db.query concat buffer

drop_index = (...) ->
  index_name = gen_index_name ...
  _, options = extract_options {...}

  buffer = { "DROP INDEX IF EXISTS #{escape_identifier index_name}" }

  if options.cascade
    append_all buffer, " CASCADE"

  db.query concat buffer

drop_table = (tname) ->
  db.query "DROP TABLE IF EXISTS #{escape_identifier tname}"

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
      -- don't use the types default default since it's not an array
      continue if k == "default" and opts.array
      opts[k] = v unless opts[k] != nil

    if opts.array
      for i=1,type(opts.array) == "number" and opts.array or 1
        out ..= "[]"

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
  enum:         C "smallint", null: false
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

