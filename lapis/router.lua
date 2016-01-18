local insert
insert = table.insert
local lpeg = require("lpeg")
local R, S, V, P
R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
local C, Cs, Ct, Cmt, Cg, Cb, Cc
C, Cs, Ct, Cmt, Cg, Cb, Cc = lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc
local encode_query_string
encode_query_string = require("lapis.util").encode_query_string
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
local route_precedence
route_precedence = function(flags)
  local p = 0
  if flags.var then
    p = p + 1
  end
  if flags.splat then
    p = p + 2
  end
  return p
end
local Router
do
  local _class_0
  local alpha, alpha_num, make_var, make_splat, make_lit, splat, var, chunk
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
      local by_precedence = { }
      local _list_0 = self.routes
      for _index_0 = 1, #_list_0 do
        local r = _list_0[_index_0]
        local pattern, flags = self:build_route(unpack(r))
        local p = route_precedence(flags)
        by_precedence[p] = by_precedence[p] or { }
        table.insert(by_precedence[p], pattern)
      end
      local precedences
      do
        local _accum_0 = { }
        local _len_0 = 1
        for k in pairs(by_precedence) do
          _accum_0[_len_0] = k
          _len_0 = _len_0 + 1
        end
        precedences = _accum_0
      end
      table.sort(precedences)
      self.p = nil
      for _index_0 = 1, #precedences do
        local p = precedences[_index_0]
        local _list_1 = by_precedence[p]
        for _index_1 = 1, #_list_1 do
          local pattern = _list_1[_index_1]
          if self.p then
            self.p = self.p + pattern
          else
            self.p = pattern
          end
        end
      end
      self.p = self.p or P(-1)
    end,
    build_route = function(self, path, responder, name)
      local pattern, flags = self.__class.route_grammar:match(path)
      pattern = pattern * -1 / function(params)
        return params, responder, path, name
      end
      return pattern, flags
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
      local patt = Cs((var / replace + 1) ^ 0)
      return patt:match(path)
    end,
    url_for = function(self, name, params, query)
      if not (name) then
        return params
      end
      local path = assert(self.named_routes[name], "Missing route named " .. tostring(name))
      path = self:fill_path(path, params, name)
      if query then
        if type(query) == "table" then
          query = encode_query_string(query)
        end
        if query ~= "" then
          path = path .. ("?" .. query)
        end
      end
      return path
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
  _class_0 = setmetatable({
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
  make_var = function(str)
    return {
      "var",
      str:sub(2)
    }
  end
  make_splat = function()
    return {
      "splat"
    }
  end
  make_lit = function(str)
    return {
      "literal",
      str
    }
  end
  splat = P("*")
  var = P(":") * alpha * alpha_num ^ 0
  chunk = var / make_var + splat / make_splat
  chunk = (1 - chunk) ^ 1 / make_lit + chunk
  self.route_grammar = Ct(chunk ^ 1) / function(parts)
    local patt
    local flags = { }
    for i, _des_0 in ipairs(parts) do
      local kind, value
      kind, value = _des_0[1], _des_0[2]
      local following = parts[i + 1]
      local exlude
      if following and following[1] == "literal" then
        exlude = following[2]
      end
      flags[kind] = true
      local part
      local _exp_0 = kind
      if "splat" == _exp_0 then
        local inside = P(1)
        if exlude then
          inside = inside - exlude
        end
        part = Cg(inside ^ 1, "splat")
      elseif "var" == _exp_0 then
        local inside = P(1) - "/"
        if exlude then
          inside = inside - exlude
        end
        part = Cg(inside ^ 1, value)
      elseif "literal" == _exp_0 then
        part = P(value)
      end
      if patt then
        patt = patt * part
      else
        patt = part
      end
    end
    return Ct(patt), flags
  end
  Router = _class_0
end
return {
  Router = Router
}
