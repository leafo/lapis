local concat = table.concat
local _G = _G
local punct = "[%^$()%.%[%]*+%-?]"
local escape_patt
escape_patt = function(str)
  return (str:gsub(punct, function(p)
    return "%" .. p
  end))
end
local html_encode_entities = {
  ['&'] = '&amp;',
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['"'] = '&quot;',
  ["'"] = '&#039;'
}
local html_decode_entities = { }
for key, value in pairs(html_encode_entities) do
  html_decode_entities[value] = key
end
local html_encode_pattern = "[" .. concat((function()
  local _accum_0 = { }
  local _len_0 = 1
  for char in pairs(html_encode_entities) do
    _accum_0[_len_0] = escape_patt(char)
    _len_0 = _len_0 + 1
  end
  return _accum_0
end)()) .. "]"
local encode
encode = function(text)
  return (text:gsub(html_encode_pattern, html_encode_entities))
end
local escape = encode
local decode
decode = function(text)
  return (text:gsub("(&[^&]-;)", function(enc)
    local decoded = html_decode_entities[enc]
    if decoded then
      return decoded
    else
      return enc
    end
  end))
end
local unescape = decode
local strip_tags
strip_tags = function(html)
  return html:gsub("<[^>]+>", "")
end
local element_attributes
element_attributes = function(buffer, t)
  if not (type(t) == "table") then
    return 
  end
  local padded = false
  for k, v in pairs(t) do
    if type(k) == "string" and not k:match("^__") then
      if not padded then
        buffer:write(" ")
        padded = true
      end
      buffer:write(k, "=", '"', escape(tostring(v)), '"')
    end
  end
  return nil
end
local element
element = function(buffer, name, ...)
  local inner = {
    ...
  }
  do
    local _with_0 = buffer
    _with_0:write("<", name)
    element_attributes(buffer, inner[1])
    _with_0:write(">")
    _with_0:write_escaped(inner)
    _with_0:write("</", name, ">")
    return _with_0
  end
end
local Buffer
do
  local _parent_0 = nil
  local _base_0 = {
    builders = {
      html_5 = function(...)
        raw('<!DOCTYPE HTML>')
        raw('<html lang="en">')
        text(...)
        return raw('</html>')
      end
    },
    with_temp = function(self, fn)
      local old_i, old_buffer = self.i, self.buffer
      self.i = 0
      self.buffer = { }
      fn()
      do
        local _with_0 = self.buffer
        self.i, self.buffer = old_i, old_buffer
        return _with_0
      end
    end,
    make_scope = function(self)
      self.scope = setmetatable({
        [Buffer] = true
      }, {
        __index = function(scope, name)
          local handler
          local _exp_0 = name
          if "widget" == _exp_0 then
            handler = function(w)
              return w:render(self)
            end
          elseif "capture" == _exp_0 then
            handler = function(fn)
              return table.concat(self:with_temp(function()
                return fn()
              end))
            end
          elseif "element" == _exp_0 then
            handler = function(...)
              return element(self, ...)
            end
          elseif "text" == _exp_0 then
            handler = (function()
              local _base_1 = self
              local _fn_0 = _base_1.write_escaped
              return function(...)
                return _fn_0(_base_1, ...)
              end
            end)()
          elseif "raw" == _exp_0 then
            handler = (function()
              local _base_1 = self
              local _fn_0 = _base_1.write
              return function(...)
                return _fn_0(_base_1, ...)
              end
            end)()
          end
          if not (handler) then
            local default = self.old_env[name]
            if not (default == nil) then
              return default
            end
          end
          if not (handler) then
            local builder = self.builders[name]
            if not (builder == nil) then
              handler = function(...)
                return self:call(builder, ...)
              end
            end
          end
          if not (handler) then
            handler = function(...)
              return element(self, name, ...)
            end
          end
          scope[name] = handler
          return handler
        end
      })
    end,
    call = function(self, fn, ...)
      local env = getfenv(fn)
      local out = nil
      if env == self.scope then
        out = {
          fn(...)
        }
      else
        local before = self.old_env
        self.old_env = env[Buffer] and _G or env
        setfenv(fn, self.scope)
        out = {
          fn(...)
        }
        setfenv(fn, env)
        self.old_env = before
      end
      return unpack(out)
    end,
    write_escaped = function(self, ...)
      local _list_0 = {
        ...
      }
      for _index_0 = 1, #_list_0 do
        local thing = _list_0[_index_0]
        local _exp_0 = type(thing)
        if "string" == _exp_0 then
          self:write(escape(thing))
        elseif "table" == _exp_0 then
          local _list_1 = thing
          for _index_1 = 1, #_list_1 do
            local chunk = _list_1[_index_1]
            self:write_escaped(chunk)
          end
        else
          self:write(thing)
        end
      end
      return nil
    end,
    write = function(self, ...)
      local _list_0 = {
        ...
      }
      for _index_0 = 1, #_list_0 do
        local thing = _list_0[_index_0]
        local _exp_0 = type(thing)
        if "string" == _exp_0 then
          self.i = self.i + 1
          self.buffer[self.i] = thing
        elseif "number" == _exp_0 then
          self:write(tostring(thing))
        elseif "nil" == _exp_0 then
          local _ = nil
        elseif "table" == _exp_0 then
          local _list_1 = thing
          for _index_1 = 1, #_list_1 do
            local chunk = _list_1[_index_1]
            self:write(chunk)
          end
        elseif "function" == _exp_0 then
          self:call(thing)
        else
          error("don't know how to handle: " .. type(thing))
        end
      end
      return nil
    end
  }
  _base_0.__index = _base_0
  if _parent_0 then
    setmetatable(_base_0, _parent_0.__base)
  end
  local _class_0 = setmetatable({
    __init = function(self, buffer)
      self.buffer = buffer
      self.old_env = { }
      self.i = #self.buffer
      return self:make_scope()
    end,
    __base = _base_0,
    __name = "Buffer",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil and _parent_0 then
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
  if _parent_0 and _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Buffer = _class_0
end
local html_writer
html_writer = function(fn)
  return function(buffer)
    return Buffer(buffer):write(fn)
  end
end
local render_html
render_html = function(fn)
  local buffer = { }
  html_writer(fn)(buffer)
  return concat(buffer)
end
local helper_key = setmetatable({ }, {
  __tostring = function()
    return "::helper_key::"
  end
})
local Widget
do
  local _parent_0 = nil
  local _base_0 = {
    _set_helper_chain = function(self, chain)
      return rawset(self, helper_key, chain)
    end,
    _get_helper_chain = function(self)
      return rawget(self, helper_key)
    end,
    include_helper = function(self, helper)
      do
        local helper_chain = self[helper_key]
        if helper_chain then
          insert(helper_chain, helper)
        else
          self:_set_helper_chain({
            helper
          })
        end
      end
      return nil
    end,
    content_for = function(self, name)
      return self._buffer:write_escaped(self[name])
    end,
    content = function(self) end,
    render_to_string = function(self, ...)
      local buffer = { }
      self:render(buffer, ...)
      return concat(buffer)
    end,
    render = function(self, buffer, ...)
      if buffer.__class == Buffer then
        self._buffer = buffer
      else
        self._buffer = Buffer(buffer)
      end
      local meta = getmetatable(self)
      local index = meta.__index
      local index_is_fn = type(index) == "function"
      local seen_helpers = { }
      local helper_chain = self:_get_helper_chain()
      local scope = setmetatable({ }, {
        __tostring = meta.__tostring,
        __index = function(scope, key)
          local value
          if index_is_fn then
            value = index(scope, key)
          else
            value = index[key]
          end
          if type(value) == "function" then
            local wrapped
            wrapped = function(...)
              return self._buffer:call(value, ...)
            end
            scope[key] = wrapped
            return wrapped
          end
          if value == nil and not seen_helpers[key] and helper_chain then
            local _list_0 = helper_chain
            for _index_0 = 1, #_list_0 do
              local h = _list_0[_index_0]
              local helper_val = h[key]
              if helper_val then
                if type(helper_val) == "function" then
                  value = function(w, ...)
                    return helper_val(h, ...)
                  end
                else
                  value = helper_val
                end
                seen_helpers[key] = true
                scope[key] = value
                return value
              end
            end
          end
          return value
        end
      })
      setmetatable(self, {
        __index = scope
      })
      self:content(...)
      setmetatable(self, meta)
      return nil
    end
  }
  _base_0.__index = _base_0
  if _parent_0 then
    setmetatable(_base_0, _parent_0.__base)
  end
  local _class_0 = setmetatable({
    __init = function(self, opts)
      if opts then
        for k, v in pairs(opts) do
          self[k] = v
        end
      end
    end,
    __base = _base_0,
    __name = "Widget",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil and _parent_0 then
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
  self.__inherited = function(self, cls)
    cls.__base.__call = function(self, ...)
      return self:render(...)
    end
  end
  if _parent_0 and _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Widget = _class_0
end
return {
  Widget = Widget,
  html_writer = html_writer,
  render_html = render_html
}
