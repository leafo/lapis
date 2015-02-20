db = require "lapis.db.mysql"

import escape_literal, escape_identifier from db
import concat from table

append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

create_table = (name, columns, opts={}) ->
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

  add ")"
  add " ENGINE=", opts.engine if opts.engine
  add " CHARSET=", opts.charset or "UTF8"
  add ";"

  db.raw_query concat buffer

drop_table = (tname) ->
  db.query "DROP TABLE IF EXISTS #{escape_identifier tname};"

class ColumnType
  default_options: { null: false }

  new: (@base, @default_options) =>

  __call: (length, opts={}) =>
    out = @base

    if type(length) == "table"
      opts = length
      length = nil

    for k,v in pairs @default_options
      opts[k] = v unless opts[k] != nil

    if l = length or opts.length
      out ..= "(#{l}"
      if d = opts.decimals
        out ..= ",#{d})"
      else
        out ..= ")"

    -- type mods

    if opts.unsigned
      out ..= " UNSIGNED"

    if opts.binary
      out ..= " BINARY"

    -- column mods

    unless opts.null
      out ..= " NOT NULL"

    if opts.default != nil
      out ..= " DEFAULT " .. escape_literal opts.default

    if opts.auto_increment
      out ..= " AUTO_INCREMENT"

    if opts.unique
      out ..= " UNIQUE"

    if opts.primary_key
      out ..= " PRIMARY KEY"

    out

  __tostring: => @__call {}


C = ColumnType
types = setmetatable {
  varchar:      C "VARCHAR", length: 255
  char:         C "CHAR"
  text:         C "TEXT"
  blob:         C "BLOB"
  bit:          C "BIT"
  tinyint:      C "TINYINT"
  smallint:     C "SMALLINT"
  mediumint:    C "MEDIUMINT"
  integer:      C "INTEGER"
  bigint:       C "BIGINT"
  float:        C "FLOAT"
  double:       C "DOUBLE"
  date:         C "DATE"
  time:         C "TIME"
  timestamp:    C "TIMESTAMP"
  datetime:     C "DATETIME"
  boolean:      C "TINYINT", length: 1
}, __index: (key) =>
  error "Don't know column type `#{key}`"


{
  -- TODO:
  -- :create_index
  -- :drop_index
  -- :add_column,
  -- :drop_column
  -- :rename_column
  -- :rename_table
  -- :entity_exists
  -- :gen_index_name

  :types
  :create_table
  :drop_table
}

