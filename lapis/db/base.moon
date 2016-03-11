
import setmetatable, getmetatable, tostring from _G

class DBRaw
raw = (val) -> setmetatable {tostring val}, DBRaw.__base
is_raw = (val) -> getmetatable(val) == DBRaw.__base

class DBList
list = (items) -> setmetatable {items}, DBList.__base
is_list = (val) -> getmetatable(val) == DBList.__base

-- is item a value we can insert into a query
is_encodable = (item) ->
  switch type(item)
    when "table"
      switch getmetatable(item)
        when DBList.__base, DBRaw.__base
          true
        else
          false
    when "function", "userdata", "nil"
      false
    else
      true

TRUE = raw"TRUE"
FALSE = raw"FALSE"
NULL = raw"NULL"

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

      if values[i] == nil
        error "missing replacement #{i} for interpolated query"

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
  encode_clause = (t, buffer) ->
    join = " AND "
    have_buffer = buffer
    buffer or= {}

    for k,v in pairs t
      if v == NULL
        append_all buffer, escape_identifier(k), " IS NULL", join
      else
        op = is_list(v) and " IN " or " = "
        append_all buffer, escape_identifier(k), op, escape_literal(v), join

    buffer[#buffer] = nil

    concat buffer unless have_buffer

  interpolate_query, encode_values, encode_assigns, encode_clause

gen_index_name = (...) ->
  -- pass index_name: "hello_world" to override generated index name
  count = select "#", ...
  last_arg = select count, ...
  if type(last_arg) == "table" and not is_raw(last_arg)
    return last_arg.index_name if last_arg.index_name

  parts = for p in *{...}
    if is_raw p
      p[1]\gsub("[^%w]+$", "")\gsub("[^%w]+", "_")
    elseif type(p) == "string"
      p
    else
      continue

  concat(parts, "_") .. "_idx"

{
  :NULL, :TRUE, :FALSE, :raw, :is_raw, :list, :is_list, :is_encodable, :format_date, :build_helpers, :gen_index_name
}
