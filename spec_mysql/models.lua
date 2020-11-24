local Model, enum
do
  local _obj_0 = require("lapis.db.mysql.model")
  Model, enum = _obj_0.Model, _obj_0.enum
end
local types, create_table
do
  local _obj_0 = require("lapis.db.mysql.schema")
  types, create_table = _obj_0.types, _obj_0.create_table
end
local drop_tables, truncate_tables
do
  local _obj_0 = require("lapis.spec.db")
  drop_tables, truncate_tables = _obj_0.drop_tables, _obj_0.truncate_tables
end
local Users
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
    __name = "Users",
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
  self.create_table = function(self)
    drop_tables(self)
    return create_table(self:table_name(), {
      {
        "id",
        types.id
      },
      {
        "name",
        types.text
      }
    })
  end
  self.truncate = function(self)
    return truncate_tables(self)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Users = _class_0
end
local Posts
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
    __name = "Posts",
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
  self.timestamp = true
  self.create_table = function(self)
    drop_tables(self)
    return create_table(self:table_name(), {
      {
        "id",
        types.id
      },
      {
        "user_id",
        types.integer({
          null = true
        })
      },
      {
        "title",
        types.text({
          null = false
        })
      },
      {
        "body",
        types.text({
          null = false
        })
      },
      {
        "created_at",
        types.datetime
      },
      {
        "updated_at",
        types.datetime
      }
    })
  end
  self.truncate = function(self)
    return truncate_tables(self)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Posts = _class_0
end
local Likes
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
    __name = "Likes",
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
  self.primary_key = {
    "user_id",
    "post_id"
  }
  self.timestamp = true
  self.relations = {
    {
      "user",
      belongs_to = "Users"
    },
    {
      "post",
      belongs_to = "Posts"
    }
  }
  self.create_table = function(self)
    drop_tables(self)
    return create_table(self:table_name(), {
      {
        "user_id",
        types.integer
      },
      {
        "post_id",
        types.integer
      },
      {
        "count",
        types.integer({
          default = 0
        })
      },
      {
        "created_at",
        types.datetime
      },
      {
        "updated_at",
        types.datetime
      },
      "PRIMARY KEY (user_id, post_id)"
    })
  end
  self.truncate = function(self)
    return truncate_tables(self)
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Likes = _class_0
end
return {
  Users = Users,
  Posts = Posts,
  Likes = Likes
}
