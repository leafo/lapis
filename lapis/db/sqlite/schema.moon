
db = require "lapis.db.sqlite"

-- https://www.sqlite.org/lang_createtable.html
create_table = (name, columns, opts={}) ->
  prefix = if opts.if_not_exists
    "CREATE TABLE IF NOT EXISTS "
  else
    "CREATE TABLE "

  buffer = {prefix, db.escape_identifier(name), " ("}
  add = (first, ...) ->
    return unless first
    table.insert buffer, first
    add ...

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
  numeric:    C "NUMERIC"
  any:    C "ANY"
}, __index: (key) =>
  error "Don't know column type `#{key}`"

{:types, :create_table, :delete_table}
