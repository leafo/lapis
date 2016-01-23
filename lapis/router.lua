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
local RouteParser
do
  local _class_0
  local _base_0 = {
    parse = function(self, route)
      return self.grammar:match(route)
    end,
    compile_exclude = function(self, current_p, chunks, k)
      if k == nil then
        k = 1
      end
      local out
      for _index_0 = k, #chunks do
        local _continue_0 = false
        repeat
          local _des_0 = chunks[_index_0]
          local kind, value, val_params
          kind, value, val_params = _des_0[1], _des_0[2], _des_0[3]
          local _exp_0 = kind
          if "literal" == _exp_0 then
            if out then
              out = out + value
            else
              out = value
            end
            break
          elseif "optional" == _exp_0 then
            local p = route_precedence(val_params)
            if current_p < p then
              _continue_0 = true
              break
            end
            if out then
              out = out + value
            else
              out = value
            end
          else
            break
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return out
    end,
    compile_chunks = function(self, chunks, exclude)
      if exclude == nil then
        exclude = nil
      end
      local patt
      local flags = { }
      for i = #chunks, 1, -1 do
        local chunk = chunks[i]
        local kind, value, val_params
        kind, value, val_params = chunk[1], chunk[2], chunk[3]
        flags[kind] = true
        local chunk_pattern
        local _exp_0 = kind
        if "splat" == _exp_0 then
          local inside = P(1)
          if exclude then
            inside = inside - exclude
          end
          exclude = nil
          chunk_pattern = Cg(inside ^ 1, "splat")
        elseif "var" == _exp_0 then
          local char = val_params and self:compile_character_class(val_params) or P(1)
          local inside = char - "/"
          if exclude then
            inside = inside - exclude
          end
          exclude = nil
          chunk_pattern = Cg(inside ^ 1, value)
        elseif "literal" == _exp_0 then
          exclude = P(value)
          chunk_pattern = P(value)
        elseif "optional" == _exp_0 then
          local inner, inner_flags, inner_exclude = self:compile_chunks(value, exclude)
          for k, v in pairs(inner_flags) do
            flags[k] = flags[k] or v
          end
          if inner_exclude then
            if exclude then
              exclude = inner_exclude + exclude
            else
              exclude = inner_exclude
            end
          end
          chunk_pattern = inner ^ -1
        else
          chunk_pattern = error("unknown node: " .. tostring(kind))
        end
        if patt then
          patt = chunk_pattern * patt
        else
          patt = chunk_pattern
        end
      end
      return patt, flags, exclude
    end,
    compile_character_class = function(self, chars)
      self.character_class_pattern = self.character_class_pattern or Ct(C("^") ^ -1 * C(P("%") * S("adw") + (C(1) * P("-") * C(1) / function(a, b)
        return tostring(a) .. tostring(b)
      end) + 1) ^ 1)
      local negate = false
      local plain_chars = { }
      local patterns
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.character_class_pattern:match(chars)
        for _index_0 = 1, #_list_0 do
          local _continue_0 = false
          repeat
            local item = _list_0[_index_0]
            local _exp_0 = item
            if "^" == _exp_0 then
              negate = true
              _continue_0 = true
              break
            elseif "%a" == _exp_0 then
              _accum_0[_len_0] = R("az", "AZ")
            elseif "%d" == _exp_0 then
              _accum_0[_len_0] = R("09")
            elseif "%w" == _exp_0 then
              _accum_0[_len_0] = R("09", "az", "AZ")
            else
              if #item == 2 then
                _accum_0[_len_0] = R(item)
              else
                table.insert(plain_chars, item)
                _continue_0 = true
                break
              end
            end
            _len_0 = _len_0 + 1
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        patterns = _accum_0
      end
      if next(plain_chars) then
        table.insert(patterns, S(table.concat(plain_chars)))
      end
      local out
      for _index_0 = 1, #patterns do
        local p = patterns[_index_0]
        if out then
          out = out + p
        else
          out = p
        end
      end
      if negate then
        out = 1 - out
      end
      return out or P(-1)
    end,
    build_grammar = function(self)
      local alpha = R("az", "AZ", "__")
      local alpha_num = alpha + R("09")
      local make_var
      make_var = function(str, char_class)
        return {
          "var",
          str:sub(2),
          char_class
        }
      end
      local make_splat
      make_splat = function()
        return {
          "splat"
        }
      end
      local make_lit
      make_lit = function(str)
        return {
          "literal",
          str
        }
      end
      local make_optional
      make_optional = function(children)
        return {
          "optional",
          children
        }
      end
      local splat = P("*")
      local var = P(":") * alpha * alpha_num ^ 0
      var = C(var) * (P("[") * C((1 - P("]")) ^ 1) * P("]")) ^ -1
      self.var = var
      self.splat = splat
      local chunk = var / make_var + splat / make_splat
      chunk = (1 - chunk) ^ 1 / make_lit + chunk
      local compile_chunks
      do
        local _base_1 = self
        local _fn_0 = _base_1.compile_chunks
        compile_chunks = function(...)
          return _fn_0(_base_1, ...)
        end
      end
      local g = P({
        "route",
        optional_literal = (1 - P(")") - V("chunk")) ^ 1 / make_lit,
        optional_route = Ct((V("chunk") + V("optional_literal")) ^ 1),
        optional = P("(") * V("optional_route") * P(")") / make_optional,
        literal = (1 - V("chunk")) ^ 1 / make_lit,
        chunk = var / make_var + splat / make_splat + V("optional"),
        route = Ct((V("chunk") + V("literal")) ^ 1)
      })
      return g / (function()
        local _base_1 = self
        local _fn_0 = _base_1.compile_chunks
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)() / function(p, f)
        return Ct(p) * -1, f
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.grammar = self:build_grammar()
    end,
    __base = _base_0,
    __name = "RouteParser"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  RouteParser = _class_0
end
local Router
do
  local _class_0
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
      local pattern, flags = self.parser:parse(path)
      pattern = pattern / function(params)
        return params, responder, path, name
      end
      return pattern, flags
    end,
    fill_path = function(self, path, params, route_name)
      if params == nil then
        params = { }
      end
      local optional_stack
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
            if optional_stack then
              optional_stack.hits = optional_stack.hits + 1
            end
            return val, true
          else
            if optional_stack then
              optional_stack.misses = optional_stack.misses + 1
            end
            return ""
          end
        end
      end
      local patt = Cs(P({
        "string",
        replacement = self.parser.var / replace + self.parser.splat / (function()
          return replace(":splat")
        end) + V("optional"),
        optional = Cmt("(", function(_, k)
          optional_stack = {
            hits = 0,
            misses = 0,
            prev = optional_stack
          }
          return true, ""
        end) * Cmt(Cs((V("replacement") + 1 - ")") ^ 0) * P(")"), function(_, k, match)
          local result = optional_stack
          optional_stack = optional_stack.prev
          if result.hits > 0 and result.misses == 0 then
            return true, match
          else
            return true, ""
          end
        end),
        string = (V("replacement") + 1) ^ 0
      }))
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
      self.parser = RouteParser()
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
  Router = _class_0
end
return {
  Router = Router,
  RouteParser = RouteParser
}
