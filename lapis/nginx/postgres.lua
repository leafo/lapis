local concat
concat = table.concat
local raw_query
local proxy_location = "/query"
local logger
local type, tostring, pairs, select
do
  local _obj_0 = _G
  type, tostring, pairs, select = _obj_0.type, _obj_0.tostring, _obj_0.pairs, _obj_0.select
end
local FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw
do
  local _obj_0 = require("lapis.db.base")
  FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw = _obj_0.FALSE, _obj_0.NULL, _obj_0.TRUE, _obj_0.build_helpers, _obj_0.format_date, _obj_0.is_raw, _obj_0.raw
end
local backends = {
  default = function(_proxy)
    if _proxy == nil then
      _proxy = proxy_location
    end
    local parser = require("rds.parser")
    raw_query = function(str)
      if logger then
        logger.query(str)
      end
      local res, m = ngx.location.capture(_proxy, {
        body = str
      })
      local out, err = parser.parse(res.body)
      if not (out) then
        error(tostring(err) .. ": " .. tostring(str))
      end
      do
        local resultset = out.resultset
        if resultset then
          return resultset
        end
      end
      return out
    end
  end,
  raw = function(fn)
    do
      raw_query = fn
      return raw_query
    end
  end,
  pgmoon = function()
    local after_dispatch, increment_perf
    do
      local _obj_0 = require("lapis.nginx.context")
      after_dispatch, increment_perf = _obj_0.after_dispatch, _obj_0.increment_perf
    end
    local config = require("lapis.config").get()
    local pg_config = assert(config.postgres, "missing postgres configuration")
    local pgmoon_conn
    raw_query = function(str)
      local pgmoon = ngx and ngx.ctx.pgmoon or pgmoon_conn
      if not (pgmoon) then
        local Postgres
        Postgres = require("pgmoon").Postgres
        pgmoon = Postgres(pg_config)
        assert(pgmoon:connect())
        if ngx then
          ngx.ctx.pgmoon = pgmoon
          after_dispatch(function()
            return pgmoon:keepalive()
          end)
        else
          pgmoon_conn = pgmoon
        end
      end
      local start_time
      if ngx and config.measure_performance then
        ngx.update_time()
        start_time = ngx.now()
      end
      if logger then
        logger.query(str)
      end
      local res, err = pgmoon:query(str)
      if start_time then
        ngx.update_time()
        increment_perf("db_time", ngx.now() - start_time)
        increment_perf("db_count", 1)
      end
      if not res and err then
        error(tostring(str) .. "\n" .. tostring(err))
      end
      return res
    end
  end
}
local set_backend
set_backend = function(name, ...)
  if name == nil then
    name = "default"
  end
  return assert(backends[name])(...)
end
local init_logger
init_logger = function()
  if ngx or os.getenv("LAPIS_SHOW_QUERIES") then
    logger = require("lapis.logging")
  end
end
local init_db
init_db = function()
  local config = require("lapis.config").get()
  local default_backend = config.postgres and config.postgres.backend or "default"
  return set_backend(default_backend)
end
local escape_identifier
escape_identifier = function(ident)
  if type(ident) == "table" and ident[1] == "raw" then
    return ident[2]
  end
  ident = tostring(ident)
  return '"' .. (ident:gsub('"', '""')) .. '"'
end
local escape_literal
escape_literal = function(val)
  local _exp_0 = type(val)
  if "number" == _exp_0 then
    return tostring(val)
  elseif "string" == _exp_0 then
    return "'" .. tostring((val:gsub("'", "''"))) .. "'"
  elseif "boolean" == _exp_0 then
    return val and "TRUE" or "FALSE"
  elseif "table" == _exp_0 then
    if val == NULL then
      return "NULL"
    end
    if val[1] == "raw" and val[2] then
      return val[2]
    end
  end
  return error("don't know how to escape value: " .. tostring(val))
end
local interpolate_query, encode_values, encode_assigns, encode_clause = build_helpers(escape_literal, escape_identifier)
local append_all
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
raw_query = function(...)
  init_logger()
  init_db()
  return raw_query(...)
end
local query
query = function(str, ...)
  if select("#", ...) > 0 then
    str = interpolate_query(str, ...)
  end
  return raw_query(str)
end
local _select
_select = function(str, ...)
  return query("SELECT " .. str, ...)
end
local _insert
_insert = function(tbl, values, ...)
  if values._timestamp then
    values._timestamp = nil
    local time = format_date()
    values.created_at = values.created_at or time
    values.updated_at = values.updated_at or time
  end
  local buff = {
    "INSERT INTO ",
    escape_identifier(tbl),
    " "
  }
  encode_values(values, buff)
  local returning = {
    ...
  }
  if next(returning) then
    append_all(buff, " RETURNING ")
    for i, r in ipairs(returning) do
      append_all(buff, escape_identifier(r))
      if i ~= #returning then
        append_all(buff, ", ")
      end
    end
  end
  return raw_query(concat(buff))
end
local add_cond
add_cond = function(buffer, cond, ...)
  append_all(buffer, " WHERE ")
  local _exp_0 = type(cond)
  if "table" == _exp_0 then
    return encode_clause(cond, buffer)
  elseif "string" == _exp_0 then
    return append_all(buffer, interpolate_query(cond, ...))
  end
end
local _update
_update = function(table, values, cond, ...)
  if values._timestamp then
    values._timestamp = nil
    values.updated_at = values.updated_at or format_date()
  end
  local buff = {
    "UPDATE ",
    escape_identifier(table),
    " SET "
  }
  encode_assigns(values, buff)
  if cond then
    add_cond(buff, cond, ...)
  end
  return raw_query(concat(buff))
end
local _delete
_delete = function(table, cond, ...)
  local buff = {
    "DELETE FROM ",
    escape_identifier(table)
  }
  if cond then
    add_cond(buff, cond, ...)
  end
  return raw_query(concat(buff))
end
local _truncate
_truncate = function(...)
  local tables = concat((function(...)
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local t = _list_0[_index_0]
      _accum_0[_len_0] = escape_identifier(t)
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(...), ", ")
  return raw_query("TRUNCATE " .. tables .. " RESTART IDENTITY")
end
local parse_clause
do
  local grammar
  local make_grammar
  make_grammar = function()
    local basic_keywords = {
      "where",
      "having",
      "limit",
      "offset"
    }
    local P, R, C, S, Cmt, Ct, Cg, V
    do
      local _obj_0 = require("lpeg")
      P, R, C, S, Cmt, Ct, Cg, V = _obj_0.P, _obj_0.R, _obj_0.C, _obj_0.S, _obj_0.Cmt, _obj_0.Ct, _obj_0.Cg, _obj_0.V
    end
    local alpha = R("az", "AZ", "__")
    local alpha_num = alpha + R("09")
    local white = S(" \t\r\n") ^ 0
    local some_white = S(" \t\r\n") ^ 1
    local word = alpha_num ^ 1
    local single_string = P("'") * (P("''") + (P(1) - P("'"))) ^ 0 * P("'")
    local double_string = P('"') * (P('""') + (P(1) - P('"'))) ^ 0 * P('"')
    local strings = single_string + double_string
    local ci
    ci = function(str)
      S = require("lpeg").S
      local p
      for c in str:gmatch(".") do
        local char = S(tostring(c:lower()) .. tostring(c:upper()))
        if p then
          p = p * char
        else
          p = char
        end
      end
      return p * -alpha_num
    end
    local balanced_parens = P({
      P("(") * (V(1) + strings + (P(1) - ")")) ^ 0 * P(")")
    })
    local order_by = ci("order") * some_white * ci("by") / "order"
    local group_by = ci("group") * some_white * ci("by") / "group"
    local keyword = order_by + group_by
    for _index_0 = 1, #basic_keywords do
      local k = basic_keywords[_index_0]
      local part = ci(k) / k
      keyword = keyword + part
    end
    keyword = keyword * white
    local clause_content = (balanced_parens + strings + (word + P(1) - keyword)) ^ 1
    local outer_join_type = (ci("left") + ci("right") + ci("full")) * (white * ci("outer")) ^ -1
    local join_type = (ci("natural") * white) ^ -1 * ((ci("inner") + outer_join_type) * white) ^ -1
    local start_join = join_type * ci("join")
    local join_body = (balanced_parens + strings + (P(1) - start_join - keyword)) ^ 1
    local join_tuple = Ct(C(start_join) * C(join_body))
    local joins = (#start_join * Ct(join_tuple ^ 1)) / function(joins)
      return {
        "join",
        joins
      }
    end
    local clause = Ct((keyword * C(clause_content)))
    grammar = white * Ct(joins ^ -1 * clause ^ 0)
  end
  parse_clause = function(clause)
    if not (grammar) then
      make_grammar()
    end
    do
      local out = grammar:match(clause)
      if out then
        local _tbl_0 = { }
        for _index_0 = 1, #out do
          local t = out[_index_0]
          local _key_0, _val_0 = unpack(t)
          _tbl_0[_key_0] = _val_0
        end
        return _tbl_0
      end
    end
  end
end
local encode_case
encode_case = function(exp, t, on_else)
  local buff = {
    "CASE ",
    exp
  }
  for k, v in pairs(t) do
    append_all(buff, "\nWHEN ", escape_literal(k), " THEN ", escape_literal(v))
  end
  if on_else ~= nil then
    append_all(buff, "\nELSE ", escape_literal(on_else))
  end
  append_all(buff, "\nEND")
  return concat(buff)
end
return {
  query = query,
  raw = raw,
  is_raw = is_raw,
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  escape_literal = escape_literal,
  escape_identifier = escape_identifier,
  encode_values = encode_values,
  encode_assigns = encode_assigns,
  encode_clause = encode_clause,
  interpolate_query = interpolate_query,
  parse_clause = parse_clause,
  format_date = format_date,
  encode_case = encode_case,
  set_backend = set_backend,
  select = _select,
  insert = _insert,
  update = _update,
  delete = _delete,
  truncate = _truncate
}
