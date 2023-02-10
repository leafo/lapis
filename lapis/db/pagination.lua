local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local get_fields
get_fields = require("lapis.util").get_fields
local unpack = unpack or table.unpack
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
local flatten_iter
flatten_iter = function(iter)
  local current_page = iter()
  local idx = 1
  return function()
    if current_page then
      do
        local _with_0 = current_page[idx]
        idx = idx + 1
        if not (current_page[idx]) then
          current_page = iter()
          idx = 1
        end
        return _with_0
      end
    end
  end
end
local Paginator
do
  local _class_0
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
    end,
    each_item = function(self)
      return flatten_iter(self:each_page())
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, model, clause, ...)
      if clause == nil then
        clause = ""
      end
      self.model = model
      self.db = self.model.__class.db
      local param_count = select("#", ...)
      if self.db.is_clause(clause) then
        clause = self.db.interpolate_query("WHERE ?", clause)
      end
      local opts
      if param_count > 0 then
        local last = select(param_count, ...)
        if type(last) == "table" and not self.db.is_encodable(last) then
          param_count = param_count - 1
          opts = last
        end
      elseif type(clause) == "table" then
        opts = clause
        clause = ""
        opts = opts
      end
      self.per_page = self.model.per_page
      if opts then
        self.per_page = opts.per_page
      end
      if param_count > 0 then
        self._clause = self.db.interpolate_query(clause, ...)
      else
        self._clause = clause
      end
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
  local _class_0
  local _parent_0 = Paginator
  local _base_0 = {
    per_page = 10,
    each_page = function(self, page)
      if page == nil then
        page = 1
      end
      return function()
        local results = self:get_page(page)
        if next(results) then
          page = page + 1
          return results
        end
      end
    end,
    get_all = function(self)
      return self:prepare_results(self:select(self._clause, self.opts))
    end,
    get_page = function(self, page)
      page = (math.max(1, tonumber(page) or 0)) - 1
      local limit = self.db.interpolate_query(" LIMIT ? OFFSET ?", self.per_page, self.per_page * page, self.opts)
      return self:prepare_results(self:select(self._clause .. limit, self.opts))
    end,
    num_pages = function(self)
      return math.ceil(self:total_items() / self.per_page)
    end,
    has_items = function(self)
      local tbl_name = self.db.escape_identifier(self.model:table_name())
      local res
      if self.db.parse_clause then
        local parsed = self.db.parse_clause(self._clause)
        parsed.limit = "1"
        parsed.offset = nil
        parsed.order = nil
        res = self.db.query("SELECT 1 FROM " .. tostring(tbl_name) .. " " .. tostring(rebuild_query_clause(parsed)))
      else
        res = self.db.select("1 FROM " .. tostring(tbl_name) .. " " .. tostring(self._clause) .. " LIMIT 1")
      end
      return not not unpack(res)
    end,
    total_items = function(self)
      if not (self._count) then
        local tbl_name = self.db.escape_identifier(self.model:table_name())
        if self.db.parse_clause then
          local parsed = self.db.parse_clause(self._clause)
          parsed.limit = nil
          parsed.offset = nil
          parsed.order = nil
          if parsed.group then
            error("OffsetPaginator: can't calculate total items in a query with group by")
          end
          local query = "COUNT(*) AS c FROM " .. tostring(tbl_name) .. " " .. tostring(rebuild_query_clause(parsed))
          self._count = unpack(self.db.select(query)).c
        else
          local query = "COUNT(*) AS c FROM " .. tostring(tbl_name) .. " " .. tostring(self._clause)
          self._count = unpack(self.db.select(query)).c
        end
      end
      return self._count
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "OffsetPaginator",
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
  OffsetPaginator = _class_0
end
local OrderedPaginator
do
  local _class_0
  local valid_orders
  local _parent_0 = Paginator
  local _base_0 = {
    order = "ASC",
    per_page = 10,
    each_page = function(self)
      local tuple = { }
      return function()
        tuple = {
          self:get_page(unpack(tuple, 2))
        }
        if next(tuple[1]) then
          return tuple[1]
        end
      end
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
      local order_lower = order:lower()
      if not (valid_orders[order_lower]) then
        error("OrderedPaginator: invalid query order: " .. tostring(order))
      end
      local table_name = self.model:table_name()
      local prefix = self.db.escape_identifier(table_name) .. "."
      local escaped_fields
      if has_multi_fields then
        do
          local _accum_0 = { }
          local _len_0 = 1
          local _list_0 = self.field
          for _index_0 = 1, #_list_0 do
            local f = _list_0[_index_0]
            _accum_0[_len_0] = prefix .. self.db.escape_identifier(f)
            _len_0 = _len_0 + 1
          end
          escaped_fields = _accum_0
        end
      else
        escaped_fields = {
          prefix .. self.db.escape_identifier(self.field)
        }
      end
      if parsed.order then
        error("OrderedPaginator: order should not be provided for " .. tostring(self.__class.__name))
      end
      if parsed.offset or parsed.limit then
        error("OrderedPaginator: offset and limit should not be provided for " .. tostring(self.__class.__name))
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
        local op
        local _exp_0 = order:lower()
        if "asc" == _exp_0 then
          op = ">"
        elseif "desc" == _exp_0 then
          op = "<"
        end
        local pos_count = select("#", ...)
        if pos_count > #escaped_fields then
          error("OrderedPaginator: passed in too many values for paginated query (expected " .. tostring(#escaped_fields) .. ", got " .. tostring(pos_count) .. ")")
        end
        local order_clause
        if 1 == pos_count then
          order_clause = tostring(escaped_fields[1]) .. " " .. tostring(op) .. " " .. tostring(self.db.escape_literal((...)))
        else
          local positions = {
            ...
          }
          local buffer = {
            "("
          }
          for i in ipairs(positions) do
            if not (escaped_fields[i]) then
              error("passed in too many values for paginated query (expected " .. tostring(#escaped_fields) .. ", got " .. tostring(pos_count) .. ")")
            end
            insert(buffer, escaped_fields[i])
            insert(buffer, ", ")
          end
          buffer[#buffer] = nil
          insert(buffer, ") ")
          insert(buffer, op)
          insert(buffer, " (")
          for _index_0 = 1, #positions do
            local pos = positions[_index_0]
            insert(buffer, self.db.escape_literal(pos))
            insert(buffer, ", ")
          end
          buffer[#buffer] = nil
          insert(buffer, ")")
          order_clause = concat(buffer)
        end
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
  _class_0 = setmetatable({
    __init = function(self, model, field, ...)
      self.field = field
      _class_0.__parent.__init(self, model, ...)
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
  valid_orders = {
    asc = true,
    desc = true
  }
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
