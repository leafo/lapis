local db = require("lapis.db")
local assert_model
assert_model = function(primary_model, source)
  local models = require("models")
  do
    local m = models[source]
    if not (m) then
      error("failed to find model `" .. tostring(source) .. "` for relationship")
    end
    return m
  end
end
local fetch
fetch = function(self, name, opts)
  local source = opts.fetch
  assert(type(source) == "function", "Expecting function for `fetch` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  self.__base[get_method] = function(self)
    local existing = self[name]
    if existing ~= nil then
      return existing
    end
    do
      local obj = source(self)
      self[name] = obj
      return obj
    end
  end
end
local belongs_to
belongs_to = function(self, name, opts)
  local source = opts.belongs_to
  assert(type(source) == "string", "Expecting model name for `belongs_to` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  local column_name = tostring(name) .. "_id"
  self.__base[get_method] = function(self)
    if not (self[column_name]) then
      return nil
    end
    local existing = self[name]
    if existing ~= nil then
      return existing
    end
    local model = assert_model(self.__class, source)
    do
      local obj = model:find(self[column_name])
      self[name] = obj
      return obj
    end
  end
end
local has_one
has_one = function(self, name, opts)
  local source = opts.has_one
  assert(type(source) == "string", "Expecting model name for `has_one` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  self.__base[get_method] = function(self)
    local existing = self[name]
    if existing ~= nil then
      return existing
    end
    local model = assert_model(self.__class, source)
    local foreign_key = opts.key or tostring(self.__class:singular_name()) .. "_id"
    local clause = {
      [foreign_key] = self[self.__class:primary_keys()]
    }
    do
      local obj = model:find(clause)
      self[name] = obj
      return obj
    end
  end
end
local has_many
has_many = function(name, opts)
  if opts.pager == false then
    error("not yet")
  end
  local source = opts.has_many
  assert(type(source) == "string", "Expecting model name for `has_many` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  self.__base[get_method] = function(self, opts)
    local model = assert_model(self.__class, source)
    local foreign_key = opts.key or tostring(self.__class:singular_name()) .. "_id"
    local clause = {
      [foreign_key] = self[self.__class:primary_keys()]
    }
    do
      local where = opts.where
      if where then
        for k, v in pairs(where) do
          clause[k] = v
        end
      end
    end
    clause = db.encode_clause(clause)
    return model:paginated("where " .. tostring(clause), opts)
  end
end
return {
  fetch = fetch,
  belongs_to = belongs_to,
  has_one = has_one,
  has_many = has_many
}
