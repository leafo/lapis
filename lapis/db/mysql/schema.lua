local db = require("lapis.db.mysql")
local escape_literal, escape_identifier
escape_literal, escape_identifier = db.escape_literal, db.escape_identifier
local concat
concat = table.concat
local append_all
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
local create_table
create_table = function(name, columns, opts)
  if opts == nil then
    opts = { }
  end
  local buffer = {
    "CREATE TABLE IF NOT EXISTS " .. tostring(escape_identifier(name)) .. " ("
  }
  local add
  add = function(...)
    return append_all(buffer, ...)
  end
  for i, c in ipairs(columns) do
    add("\n  ")
    if type(c) == "table" then
      local kind
      name, kind = unpack(c)
      add(escape_identifier(name), " ", tostring(kind))
    else
      add(c)
    end
    if not (i == #columns) then
      add(",")
    end
  end
  if #columns > 0 then
    add("\n")
  end
  add(")")
  if opts.engine then
    add(" ENGINE=", opts.engine)
  end
  add(" CHARSET=", opts.charset or "UTF8")
  add(";")
  return db.raw_query(concat(buffer))
end
return {
  create_table = create_table
}
