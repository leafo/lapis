local html = require("lapis.html")
local accept_json
accept_json = function(self)
  do
    local accept = self.req.headers.accept
    if accept then
      local _exp_0 = type(accept)
      if "string" == _exp_0 then
        if accept:lower():match("application/json") then
          return true
        end
      elseif "table" == _exp_0 then
        for _index_0 = 1, #accept do
          local v = accept[_index_0]
          if v:lower():match("application/json") then
            return true
          end
        end
      end
    end
  end
  return false
end
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
      if accept_json(self) then
        local to_json
        to_json = require("lapis.util").to_json
        self.res.headers["Content-Type"] = "application/json"
        raw(to_json({
          error = self.err,
          traceback = self.trace,
          lapis = {
            version = require("lapis.version")
          }
        }))
        return 
      end
      return html_5(function()
        head(function()
          meta({
            charset = "UTF-8"
          })
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
