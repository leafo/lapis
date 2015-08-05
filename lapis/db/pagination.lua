local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local get_fields
get_fields = require("lapis.util").get_fields
local query_parts = {
  "where",
  "group",
  "having",
  "order",
  "limit",
  "offset"
}
local rebuild_query_clause
rebuild_query_clause = function(parsed)
  local buffer = { }
  do
    local joins = parsed.join
    if joins then
      for _index_0 = 1, #joins do
        local _des_0 = joins[_index_0]
        local join_type, join_clause
        join_type, join_clause = _des_0[1], _des_0[2]
        insert(buffer, join_type)
        insert(buffer, join_clause)
      end
    end
  end
  for _index_0 = 1, #query_parts do
    local _continue_0 = false
    repeat
      local p = query_parts[_index_0]
      local clause = parsed[p]
      if not (clause and clause ~= "") then
        _continue_0 = true
        break
      end
      if p == "order" then
        p = "order by"
      end
      if p == "group" then
        p = "group by"
      end
      insert(buffer, p)
      insert(buffer, clause)
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return concat(buffer, " ")
end
local Paginator
do
  local _base_0 = {
    select = function(self, ...)
      return self.model:select(...)
    end,
    prepare_results = function(self, items)
      do
        local pr = self.opts and self.opts.prepare_results
        if pr then
          return pr(items)
        else
          return items
        end
      end
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function(self, model, clause, ...)
      if clause == nil then
        clause = ""
      end
      self.model = model
      self.db = self.model.__class.db
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
      self._clause = self.db.interpolate_query(clause, ...)
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
      return self:prepare_results(self:select(self._clause, self.opts))
    end,
    get_page = function(self, page)
      page = (math.max(1, tonumber(page) or 0)) - 1
      return self:prepare_results(self:select(self._clause .. [[ LIMIT ? OFFSET ?]], self.per_page, self.per_page * page, self.opts))
    end,
    num_pages = function(self)
      return math.ceil(self:total_items() / self.per_page)
    end,
    has_items = function(self)
      local parsed = self.db.parse_clause(self._clause)
      parsed.limit = "1"
      parsed.offset = nil
      parsed.order = nil
      local tbl_name = self.db.escape_identifier(self.model:table_name())
      local res = self.db.query("SELECT 1 FROM " .. tostring(tbl_name) .. " " .. tostring(rebuild_query_clause(parsed)))
      return not not unpack(res)
    end,
    total_items = function(self)
      if not (self._count) then
        local parsed = self.db.parse_clause(self._clause)
        parsed.limit = nil
        parsed.offset = nil
        parsed.order = nil
        if parsed.group then
          error("Paginator can't calculate total items in a query with group by")
        end
        local tbl_name = self.db.escape_identifier(self.model:table_name())
        local query = "COUNT(*) AS c FROM " .. tostring(tbl_name) .. " " .. tostring(rebuild_query_clause(parsed))
        self._count = unpack(self.db.select(query)).c
      end
      return self._count
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
local OrderedPaginator
do
  local _parent_0 = Paginator
  local _base_0 = {
    order = "ASC",
    per_page = 10,
    each_page = function(self)
      return coroutine.wrap(function()
        local tuple = { }
        while true do
          tuple = {
            self:get_page(unpack(tuple, 2))
          }
          if next(tuple[1]) then
            coroutine.yield(tuple[1])
          else
            break
          end
        end
      end)
    end,
    get_page = function(self, ...)
      return self:get_ordered(self.order, ...)
    end,
    after = function(self, ...)
      return self:get_ordered("ASC", ...)
    end,
    before = function(self, ...)
      return self:get_ordered("DESC", ...)
    end,
    get_ordered = function(self, order, ...)
      local parsed = assert(self.db.parse_clause(self._clause))
      local has_multi_fields = type(self.field) == "table" and not self.db.is_raw(self.field)
      local escaped_fields
      if has_multi_fields then
        do
          local _accum_0 = { }
          local _len_0 = 1
          local _list_0 = self.field
          for _index_0 = 1, #_list_0 do
            local f = _list_0[_index_0]
            _accum_0[_len_0] = self.db.escape_identifier(f)
            _len_0 = _len_0 + 1
          end
          escaped_fields = _accum_0
        end
      else
        escaped_fields = {
          self.db.escape_identifier(self.field)
        }
      end
      if parsed.order then
        error("order should not be provided for " .. tostring(self.__class.__name))
      end
      if parsed.offset or parsed.limit then
        error("offset and limit should not be provided for " .. tostring(self.__class.__name))
      end
      parsed.order = table.concat((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #escaped_fields do
          local f = escaped_fields[_index_0]
          _accum_0[_len_0] = tostring(f) .. " " .. tostring(order)
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), ", ")
      if ... then
        local positions = {
          ...
        }
        local pos_count = #positions
        local orders
        do
          local _accum_0 = { }
          local _len_0 = 1
          for i, pos in ipairs(positions) do
            local field = escaped_fields[i]
            local _value_0
            local _exp_0 = order:lower()
            if "asc" == _exp_0 then
              _value_0 = tostring(field) .. " " .. tostring(i == pos_count and ">" or ">=") .. " " .. tostring(self.db.escape_literal(pos))
            elseif "desc" == _exp_0 then
              _value_0 = tostring(field) .. " " .. tostring(i == pos_count and "<" or "<=") .. " " .. tostring(self.db.escape_literal(pos))
            else
              _value_0 = error("don't know how to handle order " .. tostring(order))
            end
            _accum_0[_len_0] = _value_0
            _len_0 = _len_0 + 1
          end
          orders = _accum_0
        end
        local order_clause = table.concat(orders, " and ")
        if parsed.where then
          parsed.where = tostring(order_clause) .. " and (" .. tostring(parsed.where) .. ")"
        else
          parsed.where = order_clause
        end
      end
      parsed.limit = tostring(self.per_page)
      local query = rebuild_query_clause(parsed)
      local res = self:select(query, self.opts)
      local final = res[#res]
      res = self:prepare_results(res)
      if has_multi_fields then
        return res, get_fields(final, unpack(self.field))
      else
        return res, get_fields(final, self.field)
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, model, field, ...)
      self.field = field
      _parent_0.__init(self, model, ...)
      if self.opts and self.opts.order then
        self.order = self.opts.order
        self.opts.order = nil
      end
    end,
    __base = _base_0,
    __name = "OrderedPaginator",
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
  OrderedPaginator = _class_0
end
return {
  OffsetPaginator = OffsetPaginator,
  OrderedPaginator = OrderedPaginator,
  Paginator = Paginator
}
