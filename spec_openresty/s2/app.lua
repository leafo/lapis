local lapis = require("lapis")
local db = require("lapis.db")
local Users, Posts, Likes
do
  local _obj_0 = require("spec_mysql.models")
  Users, Posts, Likes = _obj_0.Users, _obj_0.Posts, _obj_0.Likes
end
local assert = require("luassert")
local assert_same_rows
assert_same_rows = function(a, b)
  do
    local _tbl_0 = { }
    for k, v in pairs(a) do
      _tbl_0[k] = v
    end
    a = _tbl_0
  end
  do
    local _tbl_0 = { }
    for k, v in pairs(b) do
      _tbl_0[k] = v
    end
    b = _tbl_0
  end
  a.created_at = nil
  a.updated_at = nil
  b.created_at = nil
  b.updated_at = nil
  return assert.same(a, b)
end
do
  local _class_0
  local _parent_0 = lapis.Application
  local _base_0 = {
    ["/"] = function(self)
      return {
        json = db.query("show tables like ?", "users")
      }
    end,
    ["/migrations"] = function(self)
      local create_table, types
      do
        local _obj_0 = require("lapis.db.mysql.schema")
        create_table, types = _obj_0.create_table, _obj_0.types
      end
      require("lapis.db.migrations").run_migrations({
        function(self)
          return create_table("migrated_table", {
            {
              "id",
              types.id
            },
            {
              "name",
              types.varchar
            }
          })
        end
      })
      return {
        json = {
          success = true
        }
      }
    end,
    ["/basic-model/create"] = function(self)
      local first = Users:create({
        name = "first"
      })
      local second = Users:create({
        name = "second"
      })
      assert.truthy(first.id)
      assert.same("first", first.name)
      assert.same(first.id + 1, second.id)
      assert.same("second", second.name)
      assert.same("2", Users:count())
      return {
        json = {
          success = true
        }
      }
    end,
    ["/basic-model/find"] = function(self)
      local first = Users:create({
        name = "first"
      })
      local second = Users:create({
        name = "second"
      })
      assert.same("2", Users:count())
      assert.same(first, Users:find(first.id))
      assert.same(second, Users:find(second.id))
      assert.same(second, Users:find({
        name = "second"
      }))
      assert.falsy(Users:find({
        name = "second",
        id = first.id
      }))
      assert.same(first, Users:find({
        id = tostring(first.id)
      }))
      return {
        json = {
          success = true
        }
      }
    end,
    ["/basic-model/select"] = function(self)
      local first = Users:create({
        name = "first"
      })
      local second = Users:create({
        name = "second"
      })
      local things = Users:select()
      assert.same(2, #things)
      things = Users:select("order by name desc")
      assert("second", things[1].name)
      assert("first", things[2].name)
      things = Users:select("order by id asc", {
        fields = "id"
      })
      assert.same({
        {
          id = first.id
        },
        {
          id = second.id
        }
      }, things)
      things = Users:find_all({
        first.id,
        second.id + 22
      })
      assert.same({
        first
      }, things)
      things = Users:find_all({
        first.id,
        second.id
      }, {
        where = {
          name = "second"
        }
      })
      assert.same({
        second
      }, things)
      return {
        json = {
          success = true
        }
      }
    end,
    ["/primary-key/create"] = function(self)
      local like = Likes:create({
        user_id = 40,
        post_id = 22,
        count = 1
      })
      assert.same(40, like.user_id)
      assert.same(22, like.post_id)
      assert.truthy(like.created_at)
      assert.truthy(like.updated_at)
      assert.same(like, Likes:find(40, 22))
      return {
        json = {
          success = true
        }
      }
    end,
    ["/primary-key/delete"] = function(self)
      local like = Likes:create({
        user_id = 1,
        post_id = 2,
        count = 1
      })
      local other_like = Likes:create({
        user_id = 4,
        post_id = 6,
        count = 2
      })
      like:delete()
      assert.has_error(function()
        return like:refresh()
      end)
      local remaining = Likes:select()
      assert.same(1, #remaining)
      assert_same_rows(other_like, remaining[1])
      return {
        json = {
          success = true
        }
      }
    end,
    ["/primary-key/update"] = function(self)
      local like = Likes:create({
        user_id = 1,
        post_id = 2,
        count = 1
      })
      local other_like = Likes:create({
        user_id = 4,
        post_id = 6,
        count = 2
      })
      like:update({
        count = 5
      })
      assert.same(5, like.count)
      assert_same_rows(like, Likes:find(like.user_id, like.post_id))
      assert_same_rows(other_like, Likes:find(other_like.user_id, other_like.post_id))
      return {
        json = {
          success = true
        }
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = nil,
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
  self:before_filter(function()
    Users:truncate()
    Posts:truncate()
    return Likes:truncate()
  end)
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  return _class_0
end
