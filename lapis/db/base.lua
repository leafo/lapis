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
return {
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  raw = raw,
  is_raw = is_raw,
  format_date = format_date
}
