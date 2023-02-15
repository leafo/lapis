local unpack = unpack or table.unpack
local db = require("lapis.db.sqlite")
local gen_index_name
gen_index_name = require("lapis.db.base").gen_index_name
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
        if type(col) == "table" and not db.is_raw(col) then
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
local make_add
make_add = function(buffer)
  local fn
  fn = function(first, ...)
    if not (first) then
      return 
    end
    table.insert(buffer, first)
    return fn(...)
  end
  return fn
end
local entity_exists
entity_exists = function(name)
  local res = unpack(db.query("SELECT COUNT(*) AS c FROM sqlite_master WHERE name = ?", name))
  return res and res.c > 0 or false
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
    db.escape_identifier(name),
    " ("
  }
  local add = make_add(buffer)
  for i, c in ipairs(columns) do
    add("\n  ")
    if type(c) == "table" then
      local kind
      name, kind = unpack(c)
      add(db.escape_identifier(name), " ", tostring(kind))
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
  local options = { }
  if opts and opts.strict then
    table.insert(options, "STRICT")
  end
  if opts and opts.without_rowid then
    table.insert(options, "WITHOUT ROWID")
  end
  if next(options) then
    add(" ", table.concat(options, ", "))
  end
  return db.query(table.concat(buffer))
end
local drop_table
drop_table = function(tname)
  return db.query("DROP TABLE IF EXISTS " .. tostring(db.escape_identifier(tname)))
end
local create_index
create_index = function(tname, ...)
  local index_name = gen_index_name(tname, ...)
  local columns, options = extract_options({
    ...
  })
  local prefix
  if options.unique then
    prefix = "CREATE UNIQUE INDEX "
  else
    prefix = "CREATE INDEX "
  end
  local buffer = {
    prefix
  }
  local add = make_add(buffer)
  if options.if_not_exists then
    add("IF NOT EXISTS ")
  end
  add(db.escape_identifier(index_name), " ON ", db.escape_identifier(tname), " (")
  for i, col in ipairs(columns) do
    add(db.escape_identifier(col))
    if not (i == #columns) then
      add(", ")
    end
  end
  add(")")
  if options.where then
    add(" WHERE ", options.where)
  end
  if options.when then
    error("did you mean create_index `where`?")
  end
  return db.query(table.concat(buffer))
end
local drop_index
drop_index = function(...)
  local index_name = gen_index_name(...)
  local _, options = extract_options({
    ...
  })
  local buffer = {
    "DROP INDEX IF EXISTS ",
    db.escape_identifier(index_name)
  }
  return db.query(table.concat(buffer))
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
local ColumnType
do
  local _class_0
  local _base_0 = {
    default_options = {
      null = false
    },
    __call = function(self, opts)
      local out = self.base
      for k, v in pairs(self.default_options) do
        local _continue_0 = false
        repeat
          if k == "default" and opts.array then
            _continue_0 = true
            break
          end
          if not (opts[k] ~= nil) then
            opts[k] = v
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      if opts.array then
        for i = 1, type(opts.array) == "number" and opts.array or 1 do
          out = out .. "[]"
        end
      end
      if not (opts.null) then
        out = out .. " NOT NULL"
      end
      if opts.default ~= nil then
        out = out .. (" DEFAULT " .. db.escape_literal(opts.default))
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
      return self:__call(self.default_options)
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
local types = {
  integer = C("INTEGER"),
  text = C("TEXT"),
  blob = C("BLOB"),
  real = C("REAL"),
  any = C("ANY"),
  numeric = C("NUMERIC")
}, {
  __index = function(self, key)
    return error("Don't know column type `" .. tostring(key) .. "`")
  end
}
return {
  types = types,
  create_table = create_table,
  drop_table = drop_table,
  create_index = create_index,
  drop_index = drop_index,
  add_column = add_column,
  drop_column = drop_column,
  rename_column = rename_column,
  rename_table = rename_table,
  entity_exists = entity_exists
}
