
import setmetatable, getmetatable, tostring from _G

class DBRaw
raw = (val) -> setmetatable {tostring val}, DBRaw.__base
is_raw = (val) -> getmetatable(val) == DBRaw.__base

class DBList
list = (items) -> setmetatable {items}, DBList.__base
is_list = (val) -> getmetatable(val) == DBList.__base

class DBClause
  get_operator: =>
    opts = @[2]

    if opts and opts.operator != nil
      return opts.operator

    "AND"

clause = (clause, opts) ->
  assert not getmetatable(clause), "db.clause: attempted to create clause from object that has metatable"
  setmetatable {clause, opts}, DBClause.__base

is_clause = (val) -> getmetatable(val) == DBClause.__base

unpack = unpack or table.unpack

-- is item a value we can insert into a query
is_encodable = (item) ->
  switch type(item)
    when "table"
      switch getmetatable(item)
        when DBList.__base, DBRaw.__base, DBClause.__base
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
  local encode_clause

  append_all = (t, ...) ->
    sz = #t
    for i=1, select "#", ...
      sz += 1
      t[sz] = select i, ...

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
        error "db.interpolate_query: missing replacement #{i}"

      if is_clause values[i]
        encode_clause values[i]
      else
        escape_literal values[i])

  -- (col1, col2, col3) VALUES (val1, val2, val3)
  encode_values = (t, buffer) ->
    assert next(t) != nil, "db.encode_values: passed an empty table"

    have_buffer = buffer
    buffer or= {}

    append_all buffer, "("

    tuples = [{k,v} for k,v in pairs t]
    for pair in *tuples
      append_all buffer, escape_identifier(pair[1]), ", "

    buffer[#buffer] = ") VALUES ("

    for pair in *tuples
      append_all buffer, escape_literal(pair[2]), ", "

    buffer[#buffer] = ")"

    concat buffer unless have_buffer

  -- col1 = val1, col2 = val2, col3 = val3
  encode_assigns = (t, buffer) ->
    assert next(t) != nil, "db.encode_assigns: passed an empty table"

    join = ", "
    have_buffer = buffer
    buffer or= {}

    for k,v in pairs t
      append_all buffer, escape_identifier(k), " = ", escape_literal(v), join

    buffer[#buffer] = nil

    concat buffer unless have_buffer

  -- { hello: "world", cat: db.NULL" } -> "hello" = 'world' AND "cat" IS NULL

  append_tuple = (buffer, k, v, ...) ->
    if v == NULL
      append_all buffer, escape_identifier(k), " IS NULL", ...
    else
      op = is_list(v) and " IN " or " = "
      append_all buffer, escape_identifier(k), op, escape_literal(v), ...

  encode_clause = (t, buffer) ->
    have_buffer = buffer
    buffer or= {}

    if is_clause t
      {obj, opts} = t

      unless opts and opts.allow_empty
        assert next(obj) != nil, "db.encode_clause: passed an empty clause (use allow_empty: true to permit empty clause)"

      local reset_pos, starting_pos

      if opts and opts.prefix
        reset_pos = #buffer
        append_all buffer, opts.prefix, " "
        starting_pos = #buffer

      operator = t\get_operator!

      isolate_precedence = operator and operator != ","

      idx = 0
      for k,v in pairs obj
        k_type = type k
        idx += 1

        if idx > 1
          if operator
            if operator == ","
              append_all buffer, operator, " "
            else
              append_all buffer, " ", operator, " "
          else
            append_all buffer, " "

        switch k_type
          when "string", "table"
            field = if type(k) == "table"
              assert is_raw(k) or is_list(k),
               "db.encode_clause: got unknown table as key: #{require("moon").dump k}"
              k
            elseif opts and opts.table_name
              raw "#{escape_identifier opts.table_name}.#{escape_identifier k}"
            else
              k

            if v == true
              append_all buffer, escape_identifier field
            elseif v == false
              append_all buffer, "NOT #{escape_identifier field}"
            else
              append_tuple buffer, field, v
          when "number" -- array elements
            continue unless v -- skip over false and nil numeric items

            if is_clause v
              matching_operator = operator == v\get_operator!

              if isolate_precedence and not matching_operator
                append_all buffer, "("

              encode_clause v, buffer

              if isolate_precedence and not matching_operator
                append_all buffer, ")"
            else
              if isolate_precedence
                append_all buffer, "("

              switch type v
                when "table"
                  if type(v[1]) == "string"
                    append_all buffer, interpolate_query unpack v
                  else
                    error "db.encode_clause: received an unknown table at clause index #{v}"
                when "string" -- raw query fragment
                  append_all buffer, v
                else
                  error "db.encode_clause: received an unknown value at clause index #{v}"

              if isolate_precedence
                append_all buffer, ")"
          else
            error "db.encode_clause: invalid key type in clause"

      -- didn't output anything, strip the prefix
      if reset_pos and starting_pos == #buffer
        for kk=#buffer,reset_pos,-1
          buffer[kk] = nil

    else -- no clause object, just copy over all the table fields directly
      assert next(t) != nil, "db.encode_clause: passed an empty table"
      for k,v in pairs t
        append_tuple buffer, k,v, " AND "

      -- clear the trailing " AND "
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
  :NULL, :TRUE, :FALSE
  :raw, :is_raw
  :list, :is_list
  :clause, :is_clause
  :is_encodable,
  :format_date, :build_helpers, :gen_index_name
}
