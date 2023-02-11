local logger = require("lapis.logging")
local Model
Model = require("lapis.db.model").Model
local LapisMigrations
do
  local _class_0
  local _parent_0 = Model
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "LapisMigrations",
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
  local self = _class_0
  self.primary_key = "name"
  self.exists = function(self, name)
    return self:find(tostring(name))
  end
  self.create = function(self, name)
    return _class_0.__parent.create(self, {
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
    table_name = LapisMigrations:table_name()
  end
  local schema = require("lapis.db.schema")
  local create_table, types, entity_exists
  create_table, types, entity_exists = schema.create_table, schema.types, schema.entity_exists
  return create_table(table_name, {
    {
      "name",
      types.varchar or types.text
    },
    "PRIMARY KEY(name)"
  })
end
local start_transaction
start_transaction = function()
  local db = require("lapis.db")
  local _exp_0 = db.__type
  if "mysql" == _exp_0 then
    return db.query("START TRANSACTION")
  else
    return db.query("BEGIN")
  end
end
local commit_transaction
commit_transaction = function()
  local db = require("lapis.db")
  return db.query("COMMIT")
end
local rollback_transaction
rollback_transaction = function()
  local db = require("lapis.db")
  return db.query("ROLLBACK")
end
local run_migrations
run_migrations = function(migrations, prefix, options)
  if options == nil then
    options = { }
  end
  assert(type(migrations) == "table", "expecting a table of migrations for run_migrations")
  if options.transaction == "global" then
    start_transaction()
  end
  local entity_exists
  entity_exists = require("lapis.db.schema").entity_exists
  if not (entity_exists(LapisMigrations:table_name())) then
    logger.notice("Table `" .. tostring(LapisMigrations:table_name()) .. "` does not exist, creating")
    create_migrations_table()
  end
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
  local exists
  do
    local _tbl_0 = { }
    local _list_0 = LapisMigrations:select()
    for _index_0 = 1, #_list_0 do
      local m = _list_0[_index_0]
      _tbl_0[m.name] = true
    end
    exists = _tbl_0
  end
  local count = 0
  for _, _des_0 in ipairs(tuples) do
    local name, fn
    name, fn = _des_0[1], _des_0[2]
    if prefix then
      assert(type(prefix) == "string", "got a prefix for `run_migrations` but it was not a string")
      name = tostring(prefix) .. "_" .. tostring(name)
    end
    if not (exists[tostring(name)]) then
      logger.migration(name)
      if options.transaction == "individual" then
        start_transaction()
      end
      fn(name)
      LapisMigrations:create(name)
      if options.transaction == "individual" then
        commit_transaction()
      end
      count = count + 1
    end
  end
  logger.migration_summary(count)
  if options.transaction == "global" then
    commit_transaction()
  end
end
return {
  create_migrations_table = create_migrations_table,
  run_migrations = run_migrations,
  LapisMigrations = LapisMigrations
}
