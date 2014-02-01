local etlua = require("etlua")
local loadkit = require("loadkit")
local Widget
do
  local _obj_0 = require("lapis.html")
  Widget = _obj_0.Widget
end
local locked_fn, release_fn
do
  local _obj_0 = require("lapis.util.functions")
  locked_fn, release_fn = _obj_0.locked_fn, _obj_0.release_fn
end
return loadkit.register("etlua", function(file, mod, fname)
  local fn, err = etlua.compile(file:read("*a"))
  if not (fn) then
    error("[" .. tostring(fname) .. "] " .. tostring(err))
  end
  local TemplateWidget
  do
    local _parent_0 = Widget
    local _base_0 = {
      render = function(self, buffer)
        local seen_helpers = { }
        local scope = setmetatable({ }, {
          __index = function(scope, key)
            if not seen_helpers[key] then
              local helper_value = self:_find_helper(key)
              seen_helpers[key] = true
              if helper_value ~= nil then
                scope[key] = helper_value
                return helper_value
              end
            end
          end
        })
        return table.insert(buffer, fn(scope))
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
