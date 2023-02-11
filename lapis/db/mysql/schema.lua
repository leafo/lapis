local db = require("lapis.db.mysql")
local escape_literal, escape_identifier
escape_literal, escape_identifier = db.escape_literal, db.escape_identifier
local concat
concat = table.concat
local gen_index_name
gen_index_name = require("lapis.db.base").gen_index_name
local unpack = unpack or table.unpack
local append_all
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
local extract_options
extract_options = function(cols)
  local options = { }
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #cols do
      local _continue_0 = false
      repeat
        local col = cols[_index_0]
        if type(col) == "table" and col[1] ~= "raw" then
          for k, v in pairs(col) do
            options[k] = v
          end
          _continue_0 = true
          break
        end
        local _value_0 = col
        _accum_0[_len_0] = _value_0
        _len_0 = _len_0 + 1
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    cols = _accum_0
  end
  return cols, options
end
local entity_exists
entity_exists = function(name)
  local config = require("lapis.config").get()
  local mysql_config = assert(config.mysql, "missing mysql configuration")
  local database = escape_literal(assert(mysql_config.database))
  name = escape_literal(name)
  local res = unpack(db.select("COUNT(*) AS c FROM information_schema.tables WHERE table_schema = " .. tostring(database) .. " AND table_name = " .. tostring(name) .. " LIMIT 1"))
  return tonumber(res.c) > 0
end
local create_table
create_table = function(name, columns, opts)
  if opts == nil then
    opts = { }
  end
  local prefix
  if opts.if_not_exists then
    prefix = "CREATE TABLE IF NOT EXISTS "
  else
    prefix = "CREATE TABLE "
  end
  local buffer = {
    prefix,
    escape_identifier(name),
    " ("
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
  return db.query(concat(buffer))
end
local drop_table
drop_table = function(tname)
  return db.query("DROP TABLE IF EXISTS " .. tostring(escape_identifier(tname)) .. ";")
end
local create_index
create_index = function(tname, ...)
  local index_name = gen_index_name(tname, ...)
  local columns, options = extract_options({
    ...
  })
  local buffer = {
    "CREATE"
  }
  if options.unique then
    append_all(buffer, " UNIQUE")
  end
  append_all(buffer, " INDEX ", escape_identifier(index_name))
  if options.using then
    append_all(buffer, " USING ", options.using)
  end
  append_all(buffer, " ON ", escape_identifier(tname))
  append_all(buffer, " (")
  for i, col in ipairs(columns) do
    append_all(buffer, escape_identifier(col))
    if not (i == #columns) then
      append_all(buffer, ", ")
    end
  end
  append_all(buffer, ")")
  append_all(buffer, ";")
  return db.query(concat(buffer))
end
local drop_index
drop_index = function(tname, ...)
  local index_name = gen_index_name(tname, ...)
  tname = escape_identifier(tname)
  return db.query("DROP INDEX " .. tostring(escape_identifier(index_name)) .. " on " .. tostring(tname) .. ";")
end
local add_column
add_column = function(tname, col_name, col_type)
  tname = escape_identifier(tname)
  col_name = escape_identifier(col_name)
  return db.query("ALTER TABLE " .. tostring(tname) .. " ADD COLUMN " .. tostring(col_name) .. " " .. tostring(col_type))
end
local drop_column
drop_column = function(tname, col_name)
  tname = escape_identifier(tname)
  col_name = escape_identifier(col_name)
  return db.query("ALTER TABLE " .. tostring(tname) .. " DROP COLUMN " .. tostring(col_name))
end
local rename_column
rename_column = function(tname, col_from, col_to, col_type)
  assert(col_type, "A column type is required when renaming a column")
  tname = escape_identifier(tname)
  col_from = escape_identifier(col_from)
  col_to = escape_identifier(col_to)
  return db.query("ALTER TABLE " .. tostring(tname) .. " CHANGE COLUMN " .. tostring(col_from) .. " " .. tostring(col_to) .. " " .. tostring(col_type))
end
local rename_table
rename_table = function(tname_from, tname_to)
  tname_from = escape_identifier(tname_from)
  tname_to = escape_identifier(tname_to)
  return db.query("RENAME TABLE " .. tostring(tname_from) .. " TO " .. tostring(tname_to))
end
local ColumnType
do
  local _class_0
  local _base_0 = {
    default_options = {
      null = false
    },
    __call = function(self, length, opts)
      if opts == nil then
        opts = { }
      end
      local out = self.base
      if type(length) == "table" then
        opts = length
        length = nil
      end
      for k, v in pairs(self.default_options) do
        if not (opts[k] ~= nil) then
          opts[k] = v
        end
      end
      do
        local l = length or opts.length
        if l then
          out = out .. "(" .. tostring(l)
          do
            local d = opts.decimals
            if d then
              out = out .. "," .. tostring(d) .. ")"
            else
              out = out .. ")"
            end
          end
        end
      end
      if opts.unsigned then
        out = out .. " UNSIGNED"
      end
      if opts.binary then
        out = out .. " BINARY"
      end
      if not (opts.null) then
        out = out .. " NOT NULL"
      end
      if opts.default ~= nil then
        out = out .. (" DEFAULT " .. escape_literal(opts.default))
      end
      if opts.auto_increment then
        out = out .. " AUTO_INCREMENT"
      end
      if opts.unique then
        out = out .. " UNIQUE"
      end
      if opts.primary_key then
        out = out .. " PRIMARY KEY"
      end
      return out
    end,
    __tostring = function(self)
      return self:__call({ })
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, base, default_options)
      self.base, self.default_options = base, default_options
    end,
    __base = _base_0,
    __name = "ColumnType"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  ColumnType = _class_0
end
local C = ColumnType
local types = setmetatable({
  id = C("INT", {
    auto_increment = true,
    primary_key = true
  }),
  varchar = C("VARCHAR", {
    length = 255
  }),
  char = C("CHAR"),
  text = C("TEXT"),
  blob = C("BLOB"),
  bit = C("BIT"),
  tinyint = C("TINYINT"),
  smallint = C("SMALLINT"),
  mediumint = C("MEDIUMINT"),
  integer = C("INT"),
  bigint = C("BIGINT"),
  float = C("FLOAT"),
  double = C("DOUBLE"),
  date = C("DATE"),
  time = C("TIME"),
  timestamp = C("TIMESTAMP"),
  datetime = C("DATETIME"),
  boolean = C("TINYINT", {
    length = 1
  }),
  enum = C("TINYINT UNSIGNED")
}, {
  __index = function(self, key)
    return error("Don't know column type `" .. tostring(key) .. "`")
  end
})
return {
  entity_exists = entity_exists,
  gen_index_name = gen_index_name,
  types = types,
  create_table = create_table,
  drop_table = drop_table,
  create_index = create_index,
  drop_index = drop_index,
  add_column = add_column,
  drop_column = drop_column,
  rename_column = rename_column,
  rename_table = rename_table
}
