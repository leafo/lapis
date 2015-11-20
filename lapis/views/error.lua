local html = require("lapis.html")
local ErrorPage
do
  local _class_0
  local _parent_0 = html.Widget
  local _base_0 = {
    style = function(self)
      return style({
        type = "text/css"
      }, function()
        return raw([[        body {
          color: #222;
          background: #ddd;
          font-family: sans-serif;
          margin: 20px;
        }

        h1, h2, pre {
          margin: 20px;
        }

        pre {
          white-space: pre-wrap;
        }

        .box {
          background: white;
          overflow: hidden;
          box-shadow: 1px 1px 8px gray;
          border-radius: 1px;
        }

        .footer {
          text-align: center;
          font-family: serif;
          margin: 10px;
          font-size: 12px;
          color: #A7A7A7;
        }
      ]])
      end)
    end,
    content = function(self)
      return html_5(function()
        head(function()
          title("Error")
          return self:style()
        end)
        return body(function()
          div({
            class = "box"
          }, function()
            h1("Error")
            pre(function()
              return text(self.err)
            end)
            h2("Traceback")
            return pre(function()
              return text(self.trace)
            end)
          end)
          local version = require("lapis.version")
          return div({
            class = "footer"
          }, "lapis " .. tostring(version))
        end)
      end)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "ErrorPage",
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
  ErrorPage = _class_0
  return _class_0
end
