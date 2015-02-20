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

{
  -- TODO:
  -- :types
  -- :drop_table
  -- :create_index
  -- :drop_index
  -- :add_column,
  -- :drop_column
  -- :rename_column
  -- :rename_table
  -- :entity_exists
  -- :gen_index_name

  :create_table
}

