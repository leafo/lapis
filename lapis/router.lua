local insert
do
  local _obj_0 = table
  insert = _obj_0.insert
end
local lpeg = require("lpeg")
local R, S, V, P
R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
local C, Cs, Ct, Cmt, Cg, Cb, Cc
C, Cs, Ct, Cmt, Cg, Cb, Cc = lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc
local reduce
reduce = function(items, fn)
  local count = #items
  if count == 0 then
    error("reducing 0 item list")
  end
  if count == 1 then
    return items[1]
  end
  local left = fn(items[1], items[2])
  for i = 3, count do
    left = fn(left, items[i])
  end
  return left
end
local Router
do
  local alpha, alpha_num, slug, make_var, make_splat, make_lit, splat, symbol, chunk
  local _base_0 = {
    add_route = function(self, route, responder)
      self.p = nil
      local name = nil
      if type(route) == "table" then
        name = next(route)
        route = route[name]
        if not (self.named_routes[name]) then
          self.named_routes[name] = route
        end
      end
      return insert(self.routes, {
        route,
        responder,
        name
      })
    end,
    default_route = function(self, route)
      return error("failed to find route: " .. route)
    end,
    build = function(self)
      self.p = reduce((function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.routes
        for _index_0 = 1, #_list_0 do
          local r = _list_0[_index_0]
          _accum_0[_len_0] = self:build_route(unpack(r))
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), function(a, b)
        return a + b
      end)
    end,
    build_route = function(self, path, responder, name)
      return self.__class.route_grammar:match(path) * -1 / function(params)
        return params, responder, path, name
      end
    end,
    fill_path = function(self, path, params, route_name)
      if params == nil then
        params = { }
      end
      local replace
      replace = function(s)
        local param_name = s:sub(2)
        do
          local val = params[param_name]
          if val then
            if "table" == type(val) then
              do
                local get_key = val.url_key
                if get_key then
                  val = get_key(val, route_name, param_name) or ""
                else
                  local obj_name = val.__class and val.__class.__name or type(val)
                  error("Don't know how to serialize object for url: " .. tostring(obj_name))
                end
              end
            end
            return val
          else
            return ""
          end
        end
      end
      local patt = Cs((symbol / replace + 1) ^ 0)
      return patt:match(path)
    end,
    url_for = function(self, name, params)
      if not (name) then
        return params
      end
      local path = assert(self.named_routes[name], "Missing route named " .. tostring(name))
      return self:fill_path(path, params, name)
    end,
    resolve = function(self, route, ...)
      if not (self.p) then
        self:build()
      end
      local params, responder, path, name = self.p:match(route)
      if params and responder then
        return responder(params, path, name, ...)
      else
        return self:default_route(route, params, path, name)
      end
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function(self)
      self.routes = { }
      self.named_routes = { }
    end,
    __base = _base_0,
    __name = "Router"
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
  alpha = R("az", "AZ", "__")
  alpha_num = alpha + R("09")
  slug = (P(1) - "/") ^ 1
  make_var = function(str)
    local name = str:sub(2)
    return Cg(slug, name)
  end
  make_splat = function()
    return Cg(P(1) ^ 1, "splat")
  end
  make_lit = function(str)
    return P(str)
  end
  splat = P("*")
  symbol = P(":") * alpha * alpha_num ^ 0
  chunk = symbol / make_var + splat / make_splat
  chunk = (1 - chunk) ^ 1 / make_lit + chunk
  self.route_grammar = Ct(chunk ^ 1) / function(parts)
    local patt = reduce(parts, function(a, b)
      return a * b
    end)
    return Ct(patt)
  end
  Router = _class_0
end
return {
  Router = Router
}
