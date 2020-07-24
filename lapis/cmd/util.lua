local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local escape_pattern
escape_pattern = require("lapis.util").escape_pattern
local split
split = function(str, delim)
  str = str .. delim
  local _accum_0 = { }
  local _len_0 = 1
  for part in str:gmatch("(.-)" .. escape_pattern(delim)) do
    _accum_0[_len_0] = part
    _len_0 = _len_0 + 1
  end
  return _accum_0
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
columnize = function(rows, indent, padding, wrap)
  if indent == nil then
    indent = 2
  end
  if padding == nil then
    padding = 4
  end
  if wrap == nil then
    wrap = true
  end
  local max = 0
  for _index_0 = 1, #rows do
    local row = rows[_index_0]
    max = math.max(max, #row[1])
  end
  local left_width = indent + padding + max
  local formatted
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #rows do
      local row = rows[_index_0]
      local padd = (max - #row[1]) + padding
      local _value_0 = concat({
        (" "):rep(indent),
        row[1],
        (" "):rep(padd),
        wrap and wrap_text(row[2], left_width) or row[2]
      })
      _accum_0[_len_0] = _value_0
      _len_0 = _len_0 + 1
    end
    formatted = _accum_0
  end
  return concat(formatted, "\n")
end
local get_free_port
get_free_port = function()
  local socket = require("socket")
  local sock = socket.bind("*", 0)
  local _, port = sock:getsockname()
  sock:close()
  return port
end
local default_environment
do
  local _inner
  _inner = function()
    io.stderr:write("WARNING: You called `default_environment` from the module `lapis.cmd.util`. This function has been moved to `lapis.environment`\n\n")
    _inner = require("lapis.environment").default_environment
    return _inner()
  end
  default_environment = function()
    return _inner()
  end
end
local parse_flags
parse_flags = function(input)
  local flags = { }
  local filtered
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #input do
      local _continue_0 = false
      repeat
        local arg = input[_index_0]
        do
          local flag = arg:match("^%-%-?(.+)$")
          if flag then
            local k, v = flag:match("(.-)=(.*)")
            if k then
              flags[k] = v
            else
              flags[flag] = true
            end
            _continue_0 = true
            break
          end
        end
        local _value_0 = arg
        _accum_0[_len_0] = _value_0
        _len_0 = _len_0 + 1
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    filtered = _accum_0
  end
  return flags, filtered
end
return {
  columnize = columnize,
  split = split,
  get_free_port = get_free_port,
  default_environment = default_environment,
  parse_flags = parse_flags
}
