local db = require("lapis.db")
local types = setmetatable({
  serial = "serial NOT NULL",
  varchar = "character varying(255) NOT NULL",
  varchar_nullable = "character varying(255)",
  text = "text NOT NULL",
  text_nullable = "text",
  time = "timestamp without time zone NOT NULL",
  integer = "integer NOT NULL DEFAULT 0",
  foreign_key = "integer NOT NULL",
  boolean = "boolean NOT NULL"
}, {
  __index = function(self, key)
    return error("Don't know column type `" .. tostring(key) .. "`")
  end
})
local concat = table.concat
local append_all
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
local extract_options
extract_options = function(cols)
  local options = { }
  cols = (function()
    local _accum_0 = { }
    local _len_0 = 0
    local _list_0 = cols
    for _index_0 = 1, #_list_0 do
      local _continue_0 = false
      repeat
        local col = _list_0[_index_0]
        if type(col) == "table" then
          for k, v in pairs(col) do
            options[k] = v
          end
          _continue_0 = true
          break
        end
        local _value_0 = col
        if _value_0 ~= nil then
          _len_0 = _len_0 + 1
          _accum_0[_len_0] = _value_0
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    return _accum_0
  end)()
  return cols, options
end
local entity_exists
entity_exists = function(name)
  name = db.escape_literal(name)
  local res = unpack(db.select("COUNT(*) as c from pg_class where relname = " .. tostring(name)))
  return res.c > 0
end
local create_table
create_table = function(name, columns)
  local buffer = {
    "CREATE TABLE IF NOT EXISTS " .. tostring(db.escape_identifier(name)) .. " ("
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
      add(db.escape_identifier(name), " ", kind)
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
  add(");")
  return db.query(concat(buffer))
end
local create_index
create_index = function(tname, ...)
  local parts = (function(...)
    local _accum_0 = { }
    local _len_0 = 0
    local _list_0 = {
      tname,
      ...
    }
    for _index_0 = 1, #_list_0 do
      local p = _list_0[_index_0]
      if type(p) == "string" then
        _len_0 = _len_0 + 1
        _accum_0[_len_0] = p
      end
    end
    return _accum_0
  end)(...)
  local index_name = concat(parts, "_") .. "_idx"
  if entity_exists(index_name) then
    return 
  end
  local columns, options = extract_options({
    ...
  })
  local buffer = {
    "CREATE"
  }
  if options.unique then
    append_all(buffer, " UNIQUE")
  end
  append_all(buffer, " INDEX ON " .. tostring(db.escape_identifier(tname)) .. " (")
  for i, col in ipairs(columns) do
    append_all(buffer, col)
    if not (i == #columns) then
      append_all(buffer, ", ")
    end
  end
  append_all(buffer, ");")
  return db.query(concat(buffer))
end
local drop_table
drop_table = function(tname)
  return db.query("DROP TABLE IF EXISTS " .. tostring(db.escape_identifier(tname)) .. ";")
end
local add_column
add_column = function(tname, col_name, col_type)
  tname = db.escape_identifier(tname)
  col_name = db.escape_identifier(col_name)
  return db.query("ALTER TABLE " .. tostring(tname) .. " ADD COLUMN " .. tostring(col_name) .. " " .. tostring(col_type))
end
local drop_column
drop_column = function(tname, col_name)
  tname = db.escape_identifier(tname)
  col_name = db.escape_identifier(col_name)
  return db.query("ALTER TABLE " .. tostring(tname) .. " DROP COLUMN " .. tostring(col_name))
end
local rename_column
rename_column = function(tname, col_from, col_to)
  tname = db.escape_identifier(tname)
  col_from = db.escape_identifier(col_from)
  col_to = db.escape_identifier(col_to)
  return db.query("ALTER TABLE " .. tostring(tname) .. " RENAME COLUMN " .. tostring(col_from) .. " TO " .. tostring(col_to))
end
local rename_table
rename_table = function(tname_from, tname_to)
  tname_from = db.escape_identifier(tname_from)
  tname_to = db.escape_identifier(tname_to)
  return db.query("ALTER TABLE " .. tostring(tname_from) .. " RENAME TO " .. tostring(tname_to))
end
if ... == "test" then
  db.query = print
  db.select = function()
    return {
      {
        c = 0
      }
    }
  end
  add_column("hello", "dads", types.integer)
  rename_column("hello", "dads", "cats")
  drop_column("hello", "cats")
  rename_table("hello", "world")
end
return {
  types = types,
  create_table = create_table,
  drop_table = drop_table,
  create_index = create_index,
  add_column = add_column,
  drop_column = drop_column,
  rename_column = rename_column,
  rename_table = rename_table
}
