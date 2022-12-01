local unpack = unpack or table.unpack
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
return function(clause)
  if clause == "" then
    return { }
  end
  if not (grammar) then
    make_grammar()
  end
  local parsed
  do
    local tuples = grammar:match(clause)
    if tuples then
      do
        local _tbl_0 = { }
        for _index_0 = 1, #tuples do
          local t = tuples[_index_0]
          local _key_0, _val_0 = unpack(t)
          _tbl_0[_key_0] = _val_0
        end
        parsed = _tbl_0
      end
    end
  end
  if not parsed or (not next(parsed) and not clause:match("^%s*$")) then
    return nil, "failed to parse clause: `" .. tostring(clause) .. "`"
  end
  return parsed
end
