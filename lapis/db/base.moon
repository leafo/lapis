
NULL = {}

raw = (val) -> {"raw", tostring(val)}
is_raw = (val) ->
  type(val) == "table" and val[1] == "raw" and val[2]

set = (items) -> {"set", items}
is_set = (val) ->
  type(val) == "table" and val[1] == "set" and val[2]

TRUE = raw"TRUE"
FALSE = raw"FALSE"

import concat from table
import select from _G

format_date = (time) ->
  os.date "!%Y-%m-%d %H:%M:%S", time

build_helpers = (escape_literal, escape_identifier) ->
  append_all = (t, ...) ->
    for i=1, select "#", ...
      t[#t + 1] = select i, ...

  flatten_set = (set) ->
    escaped_items = [escape_literal item for item in set[2]]
    assert escaped_items[1], "can't flatten empty set"
    "(#{table.concat escaped_items, ", "})"

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
  encode_assigns = (t, buffer) ->
    join = ", "
    have_buffer = buffer
    buffer or= {}

    for k,v in pairs t
      append_all buffer, escape_identifier(k), " = ", escape_literal(v), join

    buffer[#buffer] = nil

    concat buffer unless have_buffer

  -- { hello: "world", cat: db.NULL" } -> "hello" = 'world' AND "cat" IS NULL
  encode_clause = (t, buffer)->
    join = " AND "
    have_buffer = buffer
    buffer or= {}

    for k,v in pairs t
      if v == NULL
        append_all buffer, escape_identifier(k), " IS NULL", join
      elseif is_set v
        append_all buffer, escape_identifier(k), " in ", flatten_set(v), join
      else
        append_all buffer, escape_identifier(k), " = ", escape_literal(v), join

    buffer[#buffer] = nil

    concat buffer unless have_buffer

  interpolate_query, encode_values, encode_assigns, encode_clause

gen_index_name = (...) ->
  parts = for p in *{...}
    if is_raw p
      p[2]\gsub("[^%w]+$", "")\gsub("[^%w]+", "_")
    elseif type(p) == "string"
      p
    else
      continue

  concat(parts, "_") .. "_idx"

{
  :NULL, :TRUE, :FALSE, :raw, :is_raw, :set, :is_set, :format_date, :build_helpers, :gen_index_name
}
