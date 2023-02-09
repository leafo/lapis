local Parser, Compiler
do
  local _obj_0 = require("etlua")
  Parser, Compiler = _obj_0.Parser, _obj_0.Compiler
end
local Widget, Buffer, element, escape, CONTENT_FOR_PREFIX
do
  local _obj_0 = require("lapis.html")
  Widget, Buffer, element, escape, CONTENT_FOR_PREFIX = _obj_0.Widget, _obj_0.Buffer, _obj_0.element, _obj_0.escape, _obj_0.CONTENT_FOR_PREFIX
end
local locked_fn, release_fn
do
  local _obj_0 = require("lapis.util.functions")
  locked_fn, release_fn = _obj_0.locked_fn, _obj_0.release_fn
end
local parser = Parser()
local BufferCompiler
do
  local _class_0
  local _parent_0 = Compiler
  local _base_0 = {
    header = function(self)
      return self:push("local _tostring, _escape, _b = ...\n", "local _b_buffer = _b.buffer\n", "local _b_i\n")
    end,
    increment = function(self)
      self:push("_b_i = _b.i + 1\n")
      return self:push("_b.i = _b_i\n")
    end,
    assign = function(self, ...)
      self:push("_b_buffer[_b_i] = ", ...)
      if ... then
        return self:push("\n")
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
    __name = "BufferCompiler",
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
  BufferCompiler = _class_0
end
local EtluaWidget
do
  local _class_0
  local _parent_0 = Widget
  local _base_0 = {
    _tpl_fn = nil,
    content_for = function(self, name, val)
      local fn = self:_find_helper("get_request")
      local request = fn and fn()
      if not (request) then
        error("content_for called on a widget without a Request in the helper chain. content_for is only available in a request lifecycle")
      end
      if val == nil then
        self._buffer:write(request[CONTENT_FOR_PREFIX .. name])
        return ""
      end
      local _exp_0 = type(val)
      if "string" == _exp_0 then
        val = escape(val)
      elseif "function" == _exp_0 then
        val = val
      else
        val = error("Got unknown type for content_for value: " .. tostring(type(val)))
      end
      request.__class.support.append_content_for(request, name, val)
    end,
    has_content_for = function(self, name)
      local fn = self:_find_helper("get_request")
      local request = fn and fn()
      if not (request) then
        return false
      end
      return not not request[CONTENT_FOR_PREFIX .. name]
    end,
    _find_helper = function(self, name)
      local _exp_0 = name
      if "self" == _exp_0 then
        return self
      elseif "render" == _exp_0 then
        local _base_1 = self._buffer
        local _fn_0 = _base_1.render
        return function(...)
          return _fn_0(_base_1, ...)
        end
      elseif "widget" == _exp_0 then
        local _base_1 = self._buffer
        local _fn_0 = _base_1.render_widget
        return function(...)
          return _fn_0(_base_1, ...)
        end
      elseif "element" == _exp_0 then
        return function(...)
          return element(self._buffer, ...)
        end
      end
      do
        local chain = self:_get_helper_chain()
        if chain then
          for _index_0 = 1, #chain do
            local h = chain[_index_0]
            local helper_val = h[name]
            if helper_val ~= nil then
              local value
              if type(helper_val) == "function" then
                value = function(...)
                  return helper_val(h, ...)
                end
              else
                value = helper_val
              end
              return value
            end
          end
        end
      end
      local val = self[name]
      if val ~= nil then
        local real_value
        if type(val) == "function" then
          real_value = function(...)
            return val(self, ...)
          end
        else
          real_value = val
        end
        return real_value
      end
    end,
    render = function(self, buffer)
      if buffer.__class == Buffer then
        self._buffer = buffer
      else
        self._buffer = Buffer(buffer)
      end
      local old_widget = self._buffer.widget
      self._buffer.widget = self
      local seen_helpers = { }
      local scope = setmetatable({ }, {
        __index = function(scope, key)
          if not seen_helpers[key] then
            seen_helpers[key] = true
            local helper_value = self:_find_helper(key)
            if helper_value ~= nil then
              scope[key] = helper_value
              return helper_value
            end
          end
        end
      })
      local clone = locked_fn(self._tpl_fn)
      parser:run(clone, scope, self._buffer)
      release_fn(clone)
      self._buffer.widget = old_widget
      return nil
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "EtluaWidget",
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
  self.load = function(self, code)
    local lua_code, err = parser:compile_to_lua(code, BufferCompiler)
    local fn
    if not (err) then
      fn, err = parser:load(lua_code)
    end
    if err then
      return nil, err
    end
    local TemplateWidget
    do
      local _class_1
      local _parent_1 = EtluaWidget
      local _base_1 = {
        _tpl_fn = fn
      }
      _base_1.__index = _base_1
      setmetatable(_base_1, _parent_1.__base)
      _class_1 = setmetatable({
        __init = function(self, ...)
          return _class_1.__parent.__init(self, ...)
        end,
        __base = _base_1,
        __name = "TemplateWidget",
        __parent = _parent_1
      }, {
        __index = function(cls, name)
          local val = rawget(_base_1, name)
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
          local _self_0 = setmetatable({}, _base_1)
          cls.__init(_self_0, ...)
          return _self_0
        end
      })
      _base_1.__class = _class_1
      if _parent_1.__inherited then
        _parent_1.__inherited(_parent_1, _class_1)
      end
      TemplateWidget = _class_1
      return _class_1
    end
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  EtluaWidget = _class_0
end
return {
  EtluaWidget = EtluaWidget,
  BufferCompiler = BufferCompiler
}
