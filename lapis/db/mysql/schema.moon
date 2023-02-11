db = require "lapis.db.mysql"

import escape_literal, escape_identifier from db
import concat from table
import gen_index_name from require "lapis.db.base"

unpack = unpack or table.unpack

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
  config = require("lapis.config").get!
  mysql_config = assert config.mysql, "missing mysql configuration"
  database = escape_literal assert mysql_config.database
  name = escape_literal name
  res = unpack db.select "COUNT(*) AS c FROM information_schema.tables WHERE table_schema = #{database} AND table_name = #{name} LIMIT 1"
  tonumber(res.c) > 0

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
  add " ENGINE=", opts.engine if opts.engine
  add " CHARSET=", opts.charset or "UTF8"
  add ";"

  db.query concat buffer

drop_table = (tname) ->
  db.query "DROP TABLE IF EXISTS #{escape_identifier tname};"

create_index = (tname, ...) ->
  index_name = gen_index_name tname, ...
  columns, options = extract_options {...}

  buffer = {"CREATE"}
  append_all buffer, " UNIQUE" if options.unique

  append_all buffer, " INDEX ", escape_identifier index_name

  if options.using
    append_all buffer, " USING ", options.using

  append_all buffer, " ON ", escape_identifier tname

  append_all buffer, " ("

  for i, col in ipairs columns
    append_all buffer, escape_identifier(col)
    append_all buffer, ", " unless i == #columns

  append_all buffer, ")"

  append_all buffer, ";"
  db.query concat buffer

drop_index = (tname, ...) ->
  index_name = gen_index_name tname, ...
  tname = escape_identifier tname
  db.query "DROP INDEX #{escape_identifier index_name} on #{tname};"

add_column = (tname, col_name, col_type) ->
  tname = escape_identifier tname
  col_name = escape_identifier col_name
  db.query "ALTER TABLE #{tname} ADD COLUMN #{col_name} #{col_type}"

drop_column = (tname, col_name) ->
  tname = escape_identifier tname
  col_name = escape_identifier col_name
  db.query "ALTER TABLE #{tname} DROP COLUMN #{col_name}"

rename_column = (tname, col_from, col_to, col_type)->
  assert col_type, "A column type is required when renaming a column"
  tname = escape_identifier tname
  col_from = escape_identifier col_from
  col_to = escape_identifier col_to
  db.query "ALTER TABLE #{tname} CHANGE COLUMN #{col_from} #{col_to} #{col_type}"

rename_table = (tname_from, tname_to) ->
  tname_from = escape_identifier tname_from
  tname_to = escape_identifier tname_to
  db.query "RENAME TABLE #{tname_from} TO #{tname_to}"

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
  id:           C "INT", auto_increment: true, primary_key: true
  varchar:      C "VARCHAR", length: 255
  char:         C "CHAR"
  text:         C "TEXT"
  blob:         C "BLOB"
  bit:          C "BIT"
  tinyint:      C "TINYINT"
  smallint:     C "SMALLINT"
  mediumint:    C "MEDIUMINT"
  integer:      C "INT"
  bigint:       C "BIGINT"
  float:        C "FLOAT"
  double:       C "DOUBLE"
  date:         C "DATE"
  time:         C "TIME"
  timestamp:    C "TIMESTAMP"
  datetime:     C "DATETIME"
  boolean:      C "TINYINT", length: 1
  enum:         C "TINYINT UNSIGNED"
}, __index: (key) =>
  error "Don't know column type `#{key}`"


{
  :entity_exists
  :gen_index_name

  :types
  :create_table
  :drop_table
  :create_index
  :drop_index
  :add_column
  :drop_column
  :rename_column
  :rename_table
}

