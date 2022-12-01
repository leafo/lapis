unpack = unpack or table.unpack

local grammar

-- this parses a query fragment to extract the where, having, limit, and offset
-- portions of the query. This is used by the paginator in order to manipulate
-- the query for fetching additional pages

make_grammar = ->
  basic_keywords = {"where", "having", "limit", "offset"}

  import P, R, C, S, Cmt, Ct, Cg, V from require "lpeg"

  alpha = R("az", "AZ", "__")
  alpha_num = alpha + R("09")
  white = S" \t\r\n"^0
  some_white = S" \t\r\n"^1
  word = alpha_num^1

  single_string = P"'" * (P"''" + (P(1) - P"'"))^0 * P"'"
  double_string = P'"' * (P'""' + (P(1) - P'"'))^0 * P'"'
  strings = single_string + double_string

  -- case insensitive word
  ci = (str) ->
    import S from require "lpeg"
    local p

    for c in str\gmatch "."
      char = S"#{c\lower!}#{c\upper!}"
      p = if p
        p * char
      else
        char
    p * -alpha_num

  balanced_parens = P {
    P"(" * (V(1) + strings + (P(1) - ")"))^0  * P")"
  }

  order_by = ci"order" * some_white * ci"by" / "order"
  group_by = ci"group" * some_white * ci"by" / "group"

  keyword = order_by + group_by

  for k in *basic_keywords
    part = ci(k) / k
    keyword += part

  keyword = keyword * white
  clause_content = (balanced_parens + strings + (word + P(1) - keyword))^1

  outer_join_type = (ci"left" + ci"right" + ci"full") * (white * ci"outer")^-1
  join_type = (ci"natural" * white)^-1 * ((ci"inner" + outer_join_type) * white)^-1
  start_join = join_type * ci"join"

  join_body = (balanced_parens + strings + (P(1) - start_join - keyword))^1
  join_tuple = Ct C(start_join) * C(join_body)

  joins = (#start_join * Ct join_tuple^1) / (joins) -> {"join", joins}

  clause = Ct (keyword * C clause_content)
  grammar = white * Ct joins^-1 * clause^0

(clause) ->
  return {} if clause == ""

  make_grammar! unless grammar

  parsed = if tuples = grammar\match clause
    { unpack t for t in *tuples }

  if not parsed or (not next(parsed) and not clause\match "^%s*$")
    return nil, "failed to parse clause: `#{clause}`"

  parsed
