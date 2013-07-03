local db = require("lapis.db")
local logger = require("lapis.logging")
local Model
do
  local _obj_0 = require("lapis.db.model")
  Model = _obj_0.Model
end
local LapisMigrations
do
  local _parent_0 = Model
  local _base_0 = {
    primary_key = "name"
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "LapisMigrations",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        return _parent_0[name]
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
  local self = _class_0
  self.exists = function(self, name)
    return self:find(tostring(name))
  end
  self.create = function(self, name)
    return Model.create(self, {
      name = tostring(name)
    })
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  LapisMigrations = _class_0
end
local create_migrations_table
create_migrations_table = function(table_name)
  if table_name == nil then
    table_name = "lapis_migrations"
  end
  local schema = require("lapis.db.schema")
  local create_table, types
  create_table, types = schema.create_table, schema.types
  return create_table(table_name, {
    {
      "name",
      types.varchar
    },
    "PRIMARY KEY(name)"
  })
end
local run_migrations
run_migrations = function(migrations)
  local tuples
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k, v in pairs(migrations) do
      _accum_0[_len_0] = {
        k,
        v
      }
      _len_0 = _len_0 + 1
    end
    tuples = _accum_0
  end
  table.sort(tuples, function(a, b)
    return a[1] < b[1]
  end)
  for _, _des_0 in ipairs(tuples) do
    local name, fn
    name, fn = _des_0[1], _des_0[2]
    if not (LapisMigrations:exists(name)) then
      logger.migration(name)
      fn(name)
      LapisMigrations:create(name)
    end
  end
end
return {
  create_migrations_table = create_migrations_table,
  run_migrations = run_migrations,
  LapisMigrations = LapisMigrations
}
