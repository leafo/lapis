local NULL = { }
local raw
raw = function(val)
  return {
    "raw",
    tostring(val)
  }
end
local is_raw
is_raw = function(val)
  return type(val) == "table" and val[1] == "raw" and val[2]
end
local TRUE = raw("TRUE")
local FALSE = raw("FALSE")
local format_date
format_date = function(time)
  return os.date("!%Y-%m-%d %H:%M:%S", time)
end
local build_helpers
build_helpers = function(escape_literal, escape_identifier)
  local concat
  do
    local _obj_0 = table
    concat = _obj_0.concat
  end
  local select
  do
    local _obj_0 = _G
    select = _obj_0.select
  end
  local append_all
  append_all = function(t, ...)
    for i = 1, select("#", ...) do
      t[#t + 1] = select(i, ...)
    end
  end
  local interpolate_query
  interpolate_query = function(query, ...)
    local values = {
      ...
    }
    local i = 0
    return (query:gsub("%?", function()
      i = i + 1
      return escape_literal(values[i])
    end))
  end
  local encode_values
  encode_values = function(t, buffer)
    local have_buffer = buffer
    buffer = buffer or { }
    local tuples
    do
      local _accum_0 = { }
      local _len_0 = 1
      for k, v in pairs(t) do
        _accum_0[_len_0] = {
          k,
          v
        }
        _len_0 = _len_0 + 1
      end
      tuples = _accum_0
    end
    local cols = concat((function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #tuples do
        local pair = tuples[_index_0]
        _accum_0[_len_0] = escape_identifier(pair[1])
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)(), ", ")
    local vals = concat((function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #tuples do
        local pair = tuples[_index_0]
        _accum_0[_len_0] = escape_literal(pair[2])
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)(), ", ")
    append_all(buffer, "(", cols, ") VALUES (", vals, ")")
    if not (have_buffer) then
      return concat(buffer)
    end
  end
  local encode_assigns
  encode_assigns = function(t, buffer)
    local join = ", "
    local have_buffer = buffer
    buffer = buffer or { }
    for k, v in pairs(t) do
      append_all(buffer, escape_identifier(k), " = ", escape_literal(v), join)
    end
    buffer[#buffer] = nil
    if not (have_buffer) then
      return concat(buffer)
    end
  end
  local encode_clause
  encode_clause = function(t, buffer)
    local join = " AND "
    local have_buffer = buffer
    buffer = buffer or { }
    for k, v in pairs(t) do
      if v == NULL then
        append_all(buffer, escape_identifier(k), " IS NULL", join)
      else
        append_all(buffer, escape_identifier(k), " = ", escape_literal(v), join)
      end
    end
    buffer[#buffer] = nil
    if not (have_buffer) then
      return concat(buffer)
    end
  end
  return interpolate_query, encode_values, encode_assigns, encode_clause
end
return {
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  raw = raw,
  is_raw = is_raw,
  format_date = format_date,
  build_helpers = build_helpers
}
