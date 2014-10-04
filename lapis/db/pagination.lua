local db = require("lapis.db")
local Paginator
do
  local _base_0 = { }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function(self, model, clause, ...)
      self.model = model
      local param_count = select("#", ...)
      local opts
      if param_count > 0 then
        local last = select(param_count, ...)
        opts = type(last) == "table" and last
      elseif type(clause) == "table" then
        opts = clause
        clause = ""
        opts = opts
      end
      self.per_page = self.model.per_page
      if opts then
        self.per_page = opts.per_page
      end
      if opts and opts.prepare_results then
        self.prepare_results = opts.prepare_results
      end
      self._clause = db.interpolate_query(clause, ...)
      self.opts = opts
    end,
    __base = _base_0,
    __name = "Paginator"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Paginator = _class_0
end
local OffsetPaginator
do
  local _parent_0 = Paginator
  local _base_0 = {
    per_page = 10,
    each_page = function(self, starting_page)
      if starting_page == nil then
        starting_page = 1
      end
      return coroutine.wrap(function()
        local page = starting_page
        while true do
          local results = self:get_page(page)
          if not (next(results)) then
            break
          end
          coroutine.yield(results, page)
          page = page + 1
        end
      end)
    end,
    get_all = function(self)
      return self.prepare_results(self.model:select(self._clause, self.opts))
    end,
    get_page = function(self, page)
      page = (math.max(1, tonumber(page) or 0)) - 1
      return self.prepare_results(self.model:select(self._clause .. [[      limit ?
      offset ?
    ]], self.per_page, self.per_page * page, self.opts))
    end,
    num_pages = function(self)
      return math.ceil(self:total_items() / self.per_page)
    end,
    total_items = function(self)
      self._count = self._count or self.model:count(db.parse_clause(self._clause).where)
      return self._count
    end,
    prepare_results = function(...)
      return ...
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "OffsetPaginator",
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
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  OffsetPaginator = _class_0
end
return {
  OffsetPaginator = OffsetPaginator,
  Paginator = Paginator
}
