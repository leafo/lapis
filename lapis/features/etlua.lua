local Parser
do
  local _obj_0 = require("etlua")
  Parser = _obj_0.Parser
end
local loadkit = require("loadkit")
local Widget, Buffer
do
  local _obj_0 = require("lapis.html")
  Widget, Buffer = _obj_0.Widget, _obj_0.Buffer
end
local locked_fn, release_fn
do
  local _obj_0 = require("lapis.util.functions")
  locked_fn, release_fn = _obj_0.locked_fn, _obj_0.release_fn
end
local parser = Parser()
return loadkit.register("etlua", function(file, mod, fname)
  local lua_code, err = parser:compile_to_lua(file:read("*a"))
  local fn
  if not (err) then
    fn, err = parser:load(lua_code)
  end
  if err then
    error("[" .. tostring(fname) .. "] " .. tostring(err))
  end
  local TemplateWidget
  do
    local _parent_0 = Widget
    local _base_0 = {
      content_for = function(self, name, val)
        if val then
          return _parent_0.content_for(self, name, val)
        else
          do
            val = self[name]
            if val then
              local buffer = Buffer({ })
              buffer:write(val)
              return table.concat(buffer.buffer)
            end
          end
        end
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
        local clone = locked_fn(fn)
        parser:run(clone, scope, buffer)
        release_fn(clone)
        return nil
      end
    }
    _base_0.__index = _base_0
    setmetatable(_base_0, _parent_0.__base)
    local _class_0 = setmetatable({
      __init = function(self, ...)
        return _parent_0.__init(self, ...)
      end,
      __base = _base_0,
      __name = "TemplateWidget",
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
    TemplateWidget = _class_0
    return _class_0
  end
end)
