local concat, insert
do
  local _obj_0 = table
  concat, insert = _obj_0.concat, _obj_0.insert
end
local _G = _G
local type, pairs, ipairs, tostring, getfenv, setfenv, getmetatable, setmetatable, table
type, pairs, ipairs, tostring, getfenv, setfenv, getmetatable, setmetatable, table = _G.type, _G.pairs, _G.ipairs, _G.tostring, _G.getfenv, _G.setfenv, _G.getmetatable, _G.setmetatable, _G.table
local locked_fn, release_fn
do
  local _obj_0 = require("lapis.util.functions")
  locked_fn, release_fn = _obj_0.locked_fn, _obj_0.release_fn
end
local CONTENT_FOR_PREFIX = "_content_for_"
local escape_patt
do
  local punct = "[%^$()%.%[%]*+%-?]"
  escape_patt = function(str)
    return (str:gsub(punct, function(p)
      return "%" .. p
    end))
  end
end
local html_escape_entities = {
  ['&'] = '&amp;',
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['"'] = '&quot;',
  ["'"] = '&#039;'
}
local html_unescape_entities = { }
for key, value in pairs(html_escape_entities) do
  html_unescape_entities[value] = key
end
local html_escape_pattern = "[" .. concat((function()
  local _accum_0 = { }
  local _len_0 = 1
  for char in pairs(html_escape_entities) do
    _accum_0[_len_0] = escape_patt(char)
    _len_0 = _len_0 + 1
  end
  return _accum_0
end)()) .. "]"
local escape
escape = function(text)
  return (text:gsub(html_escape_pattern, html_escape_entities))
end
local unescape
unescape = function(text)
  return (text:gsub("(&[^&]-;)", function(enc)
    local decoded = html_unescape_entities[enc]
    if decoded then
      return decoded
    else
      return enc
    end
  end))
end
local strip_tags
strip_tags = function(html)
  return html:gsub("<[^>]+>", "")
end
local void_tags = {
  "area",
  "base",
  "br",
  "col",
  "command",
  "embed",
  "hr",
  "img",
  "input",
  "keygen",
  "link",
  "meta",
  "param",
  "source",
  "track",
  "wbr"
}
for _index_0 = 1, #void_tags do
  local tag = void_tags[_index_0]
  void_tags[tag] = true
end
local classnames
classnames = function(t)
  local ccs
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k, v in pairs(t) do
      local _continue_0 = false
      repeat
        if type(k) == "number" then
          _accum_0[_len_0] = v
        else
          if not (v) then
            _continue_0 = true
            break
          end
          _accum_0[_len_0] = k
        end
        _len_0 = _len_0 + 1
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    ccs = _accum_0
  end
  return table.concat(ccs, " ")
end
local element_attributes
element_attributes = function(buffer, t)
  if not (type(t) == "table") then
    return 
  end
  for k, v in pairs(t) do
    local _continue_0 = false
    repeat
      if type(k) == "string" and not k:match("^__") then
        local vtype = type(v)
        if vtype == "boolean" then
          if v then
            buffer:write(" ", k)
          end
        else
          if vtype == "table" and k == "class" then
            v = classnames(v)
            if v == "" then
              _continue_0 = true
              break
            end
          else
            v = tostring(v)
          end
          buffer:write(" ", k, "=", '"', escape(v), '"')
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return nil
end
local element
element = function(buffer, name, attrs, ...)
  do
    local _with_0 = buffer
    _with_0:write("<", name)
    element_attributes(buffer, attrs)
    if void_tags[name] then
      local has_content = false
      local _list_0 = {
        attrs,
        ...
      }
      for _index_0 = 1, #_list_0 do
        local thing = _list_0[_index_0]
        local t = type(thing)
        local _exp_0 = t
        if "string" == _exp_0 then
          has_content = true
          break
        elseif "table" == _exp_0 then
          if thing[1] then
            has_content = true
            break
          end
        end
      end
      if not (has_content) then
        _with_0:write("/>")
        return buffer
      end
    end
    _with_0:write(">")
    _with_0:write_escaped(attrs, ...)
    _with_0:write("</", name, ">")
    return _with_0
  end
end
local Buffer
do
  local _class_0
  local _base_0 = {
    builders = {
      html_5 = function(...)
        raw('<!DOCTYPE HTML>')
        if type((...)) == "table" then
          return html(...)
        else
          return html({
            lang = "en"
          }, ...)
        end
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
            do
              local _base_1 = self
              local _fn_0 = _base_1.render_widget
              handler = function(...)
                return _fn_0(_base_1, ...)
              end
            end
          elseif "render" == _exp_0 then
            do
              local _base_1 = self
              local _fn_0 = _base_1.render
              handler = function(...)
                return _fn_0(_base_1, ...)
              end
            end
          elseif "capture" == _exp_0 then
            handler = function(fn)
              return table.concat(self:with_temp(fn))
            end
          elseif "element" == _exp_0 then
            handler = function(...)
              return element(self, ...)
            end
          elseif "text" == _exp_0 then
            do
              local _base_1 = self
              local _fn_0 = _base_1.write_escaped
              handler = function(...)
                return _fn_0(_base_1, ...)
              end
            end
          elseif "raw" == _exp_0 then
            do
              local _base_1 = self
              local _fn_0 = _base_1.write
              handler = function(...)
                return _fn_0(_base_1, ...)
              end
            end
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
    render = function(self, mod_name, ...)
      local widget = require(mod_name)
      return self:render_widget(widget(...))
    end,
    render_widget = function(self, w)
      if w.__init and w.__base then
        w = w()
      end
      do
        local current = self.widget
        if current then
          w:_inherit_helpers(current)
        end
      end
      return w:render(self)
    end,
    call = function(self, fn, ...)
      local env = getfenv(fn)
      if env == self.scope then
        return fn()
      end
      local before = self.old_env
      self.old_env = env
      local clone = locked_fn(fn)
      setfenv(clone, self.scope)
      local out = {
        clone(...)
      }
      release_fn(clone)
      self.old_env = before
      return unpack(out)
    end,
    write_escaped = function(self, thing, next_thing, ...)
      local _exp_0 = type(thing)
      if "string" == _exp_0 then
        self:write(escape(thing))
      elseif "table" == _exp_0 then
        for _index_0 = 1, #thing do
          local chunk = thing[_index_0]
          self:write_escaped(chunk)
        end
      else
        self:write(thing)
      end
      if next_thing then
        return self:write_escaped(next_thing, ...)
      end
    end,
    write = function(self, thing, next_thing, ...)
      local _exp_0 = type(thing)
      if "string" == _exp_0 then
        self.i = self.i + 1
        self.buffer[self.i] = thing
      elseif "number" == _exp_0 then
        self:write(tostring(thing))
      elseif "nil" == _exp_0 then
        local _ = nil
      elseif "table" == _exp_0 then
        for _index_0 = 1, #thing do
          local chunk = thing[_index_0]
          self:write(chunk)
        end
      elseif "function" == _exp_0 then
        self:call(thing)
      else
        error("don't know how to handle: " .. type(thing))
      end
      if next_thing then
        return self:write(next_thing, ...)
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, buffer)
      self.buffer = buffer
      self.old_env = { }
      self.i = #self.buffer
      return self:make_scope()
    end,
    __base = _base_0,
    __name = "Buffer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
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
  local _class_0
  local _base_0 = {
    _set_helper_chain = function(self, chain)
      return rawset(self, helper_key, chain)
    end,
    _get_helper_chain = function(self)
      return rawget(self, helper_key)
    end,
    _find_helper = function(self, name)
      do
        local chain = self:_get_helper_chain()
        if chain then
          for _index_0 = 1, #chain do
            local h = chain[_index_0]
            local helper_val = h[name]
            if helper_val ~= nil then
              local value
              if type(helper_val) == "function" then
                value = function(w, ...)
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
    end,
    _inherit_helpers = function(self, other)
      self._parent = other
      do
        local other_helpers = other:_get_helper_chain()
        if other_helpers then
          for _index_0 = 1, #other_helpers do
            local helper = other_helpers[_index_0]
            self:include_helper(helper)
          end
        end
      end
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
    content_for = function(self, name, val)
      local full_name = CONTENT_FOR_PREFIX .. name
      if not (val) then
        return self._buffer:write(self[full_name])
      end
      do
        local helper = self:_get_helper_chain()[1]
        if helper then
          local layout_opts = helper.layout_opts
          if type(val) == "string" then
            val = escape(val)
          else
            val = getfenv(val).capture(val)
          end
          local existing = layout_opts[full_name]
          local _exp_0 = type(existing)
          if "nil" == _exp_0 then
            layout_opts[full_name] = val
          elseif "table" == _exp_0 then
            return table.insert(layout_opts[full_name], val)
          else
            layout_opts[full_name] = {
              existing,
              val
            }
          end
        end
      end
    end,
    has_content_for = function(self, name)
      local full_name = CONTENT_FOR_PREFIX .. name
      return not not self[full_name]
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
      local old_widget = self._buffer.widget
      self._buffer.widget = self
      local meta = getmetatable(self)
      local index = meta.__index
      local index_is_fn = type(index) == "function"
      local seen_helpers = { }
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
            if Widget.__base[key] and key ~= "content" then
              wrapped = value
            else
              wrapped = function(...)
                return self._buffer:call(value, ...)
              end
            end
            scope[key] = wrapped
            return wrapped
          end
          if value == nil and not seen_helpers[key] then
            local helper_value = self:_find_helper(key)
            seen_helpers[key] = true
            if helper_value ~= nil then
              scope[key] = helper_value
              return helper_value
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
      self._buffer.widget = old_widget
      return nil
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, opts)
      if opts then
        for k, v in pairs(opts) do
          if type(k) == "string" then
            self[k] = v
          end
        end
      end
    end,
    __base = _base_0,
    __name = "Widget"
  }, {
    __index = _base_0,
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
  self.include = function(self, other_cls)
    local mixin_class
    mixin_class = require("lapis.util").mixin_class
    if type(other_cls) == "string" then
      other_cls = require(other_cls)
    end
    return mixin_class(self, other_cls)
  end
  Widget = _class_0
end
return {
  Widget = Widget,
  Buffer = Buffer,
  html_writer = html_writer,
  render_html = render_html,
  escape = escape,
  unescape = unescape,
  classnames = classnames,
  CONTENT_FOR_PREFIX = CONTENT_FOR_PREFIX
}
