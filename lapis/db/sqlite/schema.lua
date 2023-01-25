local db = require("lapis.db.sqlite")
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
  local add
  add = function(first, ...)
    if not (first) then
      return 
    end
    table.insert(buffer, first)
    return add(...)
  end
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
  numeric = C("NUMERIC"),
  any = C("ANY")
}, {
  __index = function(self, key)
    return error("Don't know column type `" .. tostring(key) .. "`")
  end
}
return {
  types = types,
  create_table = create_table,
  delete_table = delete_table
}
