local db = require("lapis.db.postgres")
local gen_index_name
gen_index_name = require("lapis.db.base").gen_index_name
local escape_literal, escape_identifier, is_raw
escape_literal, escape_identifier, is_raw = db.escape_literal, db.escape_identifier, db.is_raw
local concat
concat = table.concat
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
        if type(col) == "table" and not is_raw(col) then
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
  name = escape_literal(name)
  local res = unpack(db.select("COUNT(*) as c from pg_class where relname = " .. tostring(name)))
  return res.c > 0
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
  return db.query(concat(buffer))
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
  if options.concurrently then
    append_all(buffer, "CONCURRENTLY ")
  end
  if options.if_not_exists then
    append_all(buffer, "IF NOT EXISTS ")
  end
  append_all(buffer, escape_identifier(index_name), " ON ", escape_identifier(tname))
  if options.method then
    append_all(buffer, " USING ", options.method)
  end
  append_all(buffer, " (")
  for i, col in ipairs(columns) do
    append_all(buffer, escape_identifier(col))
    if not (i == #columns) then
      append_all(buffer, ", ")
    end
  end
  append_all(buffer, ")")
  if options.tablespace then
    append_all(buffer, " TABLESPACE ", escape_identifier(options.tablespace))
  end
  if options.where then
    append_all(buffer, " WHERE ", options.where)
  end
  if options.when then
    error("did you mean create_index `where`?")
  end
  return db.query(concat(buffer))
end
local drop_index
drop_index = function(...)
  local index_name = gen_index_name(...)
  local _, options = extract_options({
    ...
  })
  local buffer = {
    "DROP INDEX IF EXISTS " .. tostring(escape_identifier(index_name))
  }
  if options.cascade then
    append_all(buffer, " CASCADE")
  end
  return db.query(concat(buffer))
end
local drop_table
drop_table = function(tname)
  return db.query("DROP TABLE IF EXISTS " .. tostring(escape_identifier(tname)))
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
rename_column = function(tname, col_from, col_to)
  tname = escape_identifier(tname)
  col_from = escape_identifier(col_from)
  col_to = escape_identifier(col_to)
  return db.query("ALTER TABLE " .. tostring(tname) .. " RENAME COLUMN " .. tostring(col_from) .. " TO " .. tostring(col_to))
end
local rename_table
rename_table = function(tname_from, tname_to)
  tname_from = escape_identifier(tname_from)
  tname_to = escape_identifier(tname_to)
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
        out = out .. (" DEFAULT " .. escape_literal(opts.default))
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
local TimeType
do
  local _class_0
  local _parent_0 = ColumnType
  local _base_0 = {
    __tostring = ColumnType.__tostring,
    __call = function(self, opts)
      local base = self.base
      if opts.timezone then
        self.base = base .. " with time zone"
      end
      do
        local _with_0 = ColumnType.__call(self, opts)
        self.base = base
        return _with_0
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "TimeType",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  TimeType = _class_0
end
local C = ColumnType
local T = TimeType
local types = setmetatable({
  serial = C("serial"),
  varchar = C("character varying(255)"),
  text = C("text"),
  time = T("timestamp"),
  date = C("date"),
  enum = C("smallint", {
    null = false
  }),
  integer = C("integer", {
    null = false,
    default = 0
  }),
  numeric = C("numeric", {
    null = false,
    default = 0
  }),
  real = C("real", {
    null = false,
    default = 0
  }),
  double = C("double precision", {
    null = false,
    default = 0
  }),
  boolean = C("boolean", {
    null = false,
    default = false
  }),
  foreign_key = C("integer")
}, {
  __index = function(self, key)
    return error("Don't know column type `" .. tostring(key) .. "`")
  end
})
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
  entity_exists = entity_exists,
  gen_index_name = gen_index_name
}
