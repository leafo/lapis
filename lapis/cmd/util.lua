local insert, concat = table.insert, table.concat
local escape_pattern
do
  local _table_0 = require("lapis.util")
  escape_pattern = _table_0.escape_pattern
end
local split
split = function(str, delim)
  str = str .. delim
  return (function()
    local _accum_0 = { }
    local _len_0 = 1
    for part in str:gmatch("(.-)" .. escape_pattern(delim)) do
      _accum_0[_len_0] = part
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)()
end
local wrap_text
wrap_text = function(text, indent, max_width)
  if indent == nil then
    indent = 0
  end
  if max_width == nil then
    max_width = 80
  end
  local width = max_width - indent
  local words = split(text, " ")
  local pos = 1
  local lines = { }
  while pos <= #words do
    local line_len = 0
    local line = { }
    while true do
      local word = words[pos]
      if word == nil then
        break
      end
      if #word > width then
        error("can't wrap text, words too long")
      end
      if line_len + #word > width then
        break
      end
      pos = pos + 1
      insert(line, word)
      line_len = line_len + #word + 1
    end
    insert(lines, concat(line, " "))
  end
  return concat(lines, "\n" .. (" "):rep(indent))
end
local columnize
columnize = function(rows, indent, padding)
  if indent == nil then
    indent = 2
  end
  if padding == nil then
    padding = 4
  end
  local max = 0
  local _list_0 = rows
  for _index_0 = 1, #_list_0 do
    local row = _list_0[_index_0]
    max = math.max(max, #row[1])
  end
  local left_width = indent + padding + max
  local formatted = (function()
    local _accum_0 = { }
    local _len_0 = 1
    local _list_1 = rows
    for _index_0 = 1, #_list_1 do
      local row = _list_1[_index_0]
      local padd = (max - #row[1]) + padding
      local _value_0 = concat({
        (" "):rep(indent),
        row[1],
        (" "):rep(padd),
        wrap_text(row[2], left_width)
      })
      _accum_0[_len_0] = _value_0
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)()
  return concat(formatted, "\n")
end
if ... == "test" then
  print(columnize({
    {
      "hello",
      "here is some info"
    },
    {
      "what is going on",
      "this is going to be a lot of text so it wraps around the end"
    },
    {
      "this is something",
      "not so much here"
    },
    {
      "else",
      "yeah yeah yeah not so much okay goodbye"
    }
  }))
end
return {
  columnize = columnize,
  split = split
}
