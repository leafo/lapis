
unpack = unpack or table.unpack
db = require "lapis.db.sqlite"

import gen_index_name from require "lapis.db.base"

extract_options = (cols) ->
  options = {}
  cols = for col in *cols
    if type(col) == "table" and not db.is_raw(col)
      for k,v in pairs col
        options[k] = v
      continue
    col

  cols, options

make_add = (buffer) ->
  fn = (first, ...) ->
    return unless first
    table.insert buffer, first
    fn ...

  fn


entity_exists = (name) ->
  res = unpack db.query "SELECT COUNT(*) AS c FROM sqlite_master WHERE name = ?", name
  res and res.c > 0 or false

-- https://www.sqlite.org/lang_createtable.html
create_table = (name, columns, opts={}) ->
  prefix = if opts.if_not_exists
    "CREATE TABLE IF NOT EXISTS "
  else
    "CREATE TABLE "

  buffer = {prefix, db.escape_identifier(name), " ("}
  add = make_add buffer

  for i, c in ipairs columns
    add "\n  "
    if type(c) == "table"
      name, kind = unpack c
      add db.escape_identifier(name), " ", tostring kind
    else
      add c

    add "," unless i == #columns

  add "\n" if #columns > 0

  add ")"

  options = {}

  if opts and opts.strict
    table.insert options, "STRICT"

  if opts and opts.without_rowid
    table.insert options, "WITHOUT ROWID"


  if next options
    add " ", table.concat options, ", "

  db.query table.concat buffer

drop_table = (tname) ->
  db.query "DROP TABLE IF EXISTS #{db.escape_identifier tname}"

create_index = (tname, ...) ->
  index_name = gen_index_name tname, ...
  columns, options = extract_options {...}

  prefix = if options.unique
    "CREATE UNIQUE INDEX "
  else
    "CREATE INDEX "

  buffer = {prefix}
  add = make_add buffer

  add "IF NOT EXISTS " if options.if_not_exists

  add db.escape_identifier(index_name), " ON ", db.escape_identifier(tname), " ("

  for i, col in ipairs columns
    add db.escape_identifier col
    add ", " unless i == #columns

  add ")"

  if options.where
    add " WHERE ", options.where

  if options.when
    error "did you mean create_index `where`?"

  db.query table.concat buffer

drop_index = (...) ->
  index_name = gen_index_name ...
  _, options = extract_options {...}

  buffer = { "DROP INDEX IF EXISTS ", db.escape_identifier index_name }
  db.query table.concat buffer

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
      out ..= " DEFAULT " .. db.escape_literal opts.default

    if opts.unique
      out ..= " UNIQUE"

    if opts.primary_key
      out ..= " PRIMARY KEY"

    out

  __tostring: => @__call @default_options

C = ColumnType
types = {
  integer:    C "INTEGER"
  text:       C "TEXT"
  blob:       C "BLOB"
  real:       C "REAL"
  any:        C "ANY"

  -- On strict tables, only the types above are valid
  numeric:    C "NUMERIC"
}, __index: (key) =>
  error "Don't know column type `#{key}`"

{:types, :create_table, :drop_table, :create_index, :drop_index, :add_column, :drop_column, :rename_column, :rename_table, :entity_exists}
