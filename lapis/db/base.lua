local setmetatable, getmetatable, tostring
do
  local _obj_0 = _G
  setmetatable, getmetatable, tostring = _obj_0.setmetatable, _obj_0.getmetatable, _obj_0.tostring
end
local DBRaw
do
  local _class_0
  local _base_0 = { }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "DBRaw"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  DBRaw = _class_0
end
local raw
raw = function(val)
  return setmetatable({
    tostring(val)
  }, DBRaw.__base)
end
local is_raw
is_raw = function(val)
  return getmetatable(val) == DBRaw.__base
end
local DBList
do
  local _class_0
  local _base_0 = { }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "DBList"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  DBList = _class_0
end
local list
list = function(items)
  return setmetatable({
    items
  }, DBList.__base)
end
local is_list
is_list = function(val)
  return getmetatable(val) == DBList.__base
end
local DBClause
do
  local _class_0
  local _base_0 = {
    get_operator = function(self)
      local opts = self[2]
      if opts and opts.operator ~= nil then
        return opts.operator
      end
      return "AND"
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "DBClause"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  DBClause = _class_0
end
local clause
clause = function(clause, opts)
  assert(not getmetatable(clause), "db.clause: attempted to create clause from object that has metatable")
  return setmetatable({
    clause,
    opts
  }, DBClause.__base)
end
local is_clause
is_clause = function(val)
  return getmetatable(val) == DBClause.__base
end
local unpack = unpack or table.unpack
local is_encodable
is_encodable = function(item)
  local _exp_0 = type(item)
  if "table" == _exp_0 then
    local _exp_1 = getmetatable(item)
    if DBList.__base == _exp_1 or DBRaw.__base == _exp_1 or DBClause.__base == _exp_1 then
      return true
    else
      return false
    end
  elseif "function" == _exp_0 or "userdata" == _exp_0 or "nil" == _exp_0 then
    return false
  else
    return true
  end
end
local TRUE = raw("TRUE")
local FALSE = raw("FALSE")
local NULL = raw("NULL")
local concat
concat = table.concat
local select
select = _G.select
local format_date
format_date = function(time)
  return os.date("!%Y-%m-%d %H:%M:%S", time)
end
local build_helpers
build_helpers = function(escape_literal, escape_identifier)
  local encode_clause
  local append_all
  append_all = function(t, ...)
    local sz = #t
    for i = 1, select("#", ...) do
      sz = sz + 1
      t[sz] = select(i, ...)
    end
  end
  local flatten_set
  flatten_set = function(set)
    local escaped_items
    do
      local _accum_0 = { }
      local _len_0 = 1
      for item in set[2] do
        _accum_0[_len_0] = escape_literal(item)
        _len_0 = _len_0 + 1
      end
      escaped_items = _accum_0
    end
    assert(escaped_items[1], "can't flatten empty set")
    return "(" .. tostring(table.concat(escaped_items, ", ")) .. ")"
  end
  local interpolate_query
  interpolate_query = function(query, ...)
    local values = {
      ...
    }
    local i = 0
    return (query:gsub("%?", function()
      i = i + 1
      if values[i] == nil then
        error("db.interpolate_query: missing replacement " .. tostring(i))
      end
      if is_clause(values[i]) then
        return encode_clause(values[i])
      else
        return escape_literal(values[i])
      end
    end))
  end
  local encode_values
  encode_values = function(t, buffer)
    assert(next(t) ~= nil, "db.encode_values: passed an empty table")
    local have_buffer = buffer
    buffer = buffer or { }
    append_all(buffer, "(")
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
    for _index_0 = 1, #tuples do
      local pair = tuples[_index_0]
      append_all(buffer, escape_identifier(pair[1]), ", ")
    end
    buffer[#buffer] = ") VALUES ("
    for _index_0 = 1, #tuples do
      local pair = tuples[_index_0]
      append_all(buffer, escape_literal(pair[2]), ", ")
    end
    buffer[#buffer] = ")"
    if not (have_buffer) then
      return concat(buffer)
    end
  end
  local encode_assigns
  encode_assigns = function(t, buffer)
    assert(next(t) ~= nil, "db.encode_assigns: passed an empty table")
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
  local append_tuple
  append_tuple = function(buffer, k, v, ...)
    if v == NULL then
      return append_all(buffer, escape_identifier(k), " IS NULL", ...)
    else
      local op = is_list(v) and " IN " or " = "
      return append_all(buffer, escape_identifier(k), op, escape_literal(v), ...)
    end
  end
  encode_clause = function(t, buffer)
    local have_buffer = buffer
    buffer = buffer or { }
    if is_clause(t) then
      local obj, opts
      obj, opts = t[1], t[2]
      if not (opts and opts.allow_empty) then
        assert(next(obj) ~= nil, "db.encode_clause: passed an empty clause (use allow_empty: true to permit empty clause)")
      end
      local reset_pos, starting_pos
      if opts and opts.prefix then
        reset_pos = #buffer
        append_all(buffer, opts.prefix, " ")
        starting_pos = #buffer
      end
      local operator = t:get_operator()
      local isolate_precedence = operator and operator ~= ","
      local idx = 0
      for k, v in pairs(obj) do
        local _continue_0 = false
        repeat
          local k_type = type(k)
          idx = idx + 1
          if idx > 1 then
            if operator then
              if operator == "," then
                append_all(buffer, operator, " ")
              else
                append_all(buffer, " ", operator, " ")
              end
            else
              append_all(buffer, " ")
            end
          end
          local _exp_0 = k_type
          if "string" == _exp_0 or "table" == _exp_0 then
            local field
            if type(k) == "table" then
              assert(is_raw(k) or is_list(k), "db.encode_clause: got unknown table as key: " .. tostring(require("moon").dump(k)))
              field = k
            elseif opts and opts.table_name then
              field = raw(tostring(escape_identifier(opts.table_name)) .. "." .. tostring(escape_identifier(k)))
            else
              field = k
            end
            if v == true then
              append_all(buffer, escape_identifier(field))
            elseif v == false then
              append_all(buffer, "NOT " .. tostring(escape_identifier(field)))
            else
              append_tuple(buffer, field, v)
            end
          elseif "number" == _exp_0 then
            if not (v) then
              _continue_0 = true
              break
            end
            if is_clause(v) then
              local matching_operator = operator == v:get_operator()
              if isolate_precedence and not matching_operator then
                append_all(buffer, "(")
              end
              encode_clause(v, buffer)
              if isolate_precedence and not matching_operator then
                append_all(buffer, ")")
              end
            else
              if isolate_precedence then
                append_all(buffer, "(")
              end
              local _exp_1 = type(v)
              if "table" == _exp_1 then
                if type(v[1]) == "string" then
                  append_all(buffer, interpolate_query(unpack(v)))
                else
                  error("db.encode_clause: received an unknown table at clause index " .. tostring(v))
                end
              elseif "string" == _exp_1 then
                append_all(buffer, v)
              else
                error("db.encode_clause: received an unknown value at clause index " .. tostring(v))
              end
              if isolate_precedence then
                append_all(buffer, ")")
              end
            end
          else
            error("db.encode_clause: invalid key type in clause")
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      if reset_pos and starting_pos == #buffer then
        for kk = #buffer, reset_pos, -1 do
          buffer[kk] = nil
        end
      end
    else
      assert(next(t) ~= nil, "db.encode_clause: passed an empty table")
      for k, v in pairs(t) do
        append_tuple(buffer, k, v, " AND ")
      end
      buffer[#buffer] = nil
    end
    if not (have_buffer) then
      return concat(buffer)
    end
  end
  return interpolate_query, encode_values, encode_assigns, encode_clause
end
local gen_index_name
gen_index_name = function(...)
  local count = select("#", ...)
  local last_arg = select(count, ...)
  if type(last_arg) == "table" and not is_raw(last_arg) then
    if last_arg.index_name then
      return last_arg.index_name
    end
  end
  local parts
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local _continue_0 = false
      repeat
        local p = _list_0[_index_0]
        if is_raw(p) then
          _accum_0[_len_0] = p[1]:gsub("[^%w]+$", ""):gsub("[^%w]+", "_")
        elseif type(p) == "string" then
          _accum_0[_len_0] = p
        else
          _continue_0 = true
          break
        end
        _len_0 = _len_0 + 1
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    parts = _accum_0
  end
  return concat(parts, "_") .. "_idx"
end
return {
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  raw = raw,
  is_raw = is_raw,
  list = list,
  is_list = is_list,
  clause = clause,
  is_clause = is_clause,
  is_encodable = is_encodable,
  format_date = format_date,
  build_helpers = build_helpers,
  gen_index_name = gen_index_name
}
