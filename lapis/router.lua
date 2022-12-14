local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local unpack = unpack or table.unpack
local lpeg = require("lpeg")
local R, S, V, P
R, S, V, P = lpeg.R, lpeg.S, lpeg.V, lpeg.P
local C, Cs, Ct, Cmt, Cg, Cb, Cc
C, Cs, Ct, Cmt, Cg, Cb, Cc = lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc
local encode_query_string
encode_query_string = require("lapis.util").encode_query_string
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
            local p = self:route_precedence(val_params)
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
        local _update_0 = kind
        flags[_update_0] = flags[_update_0] or 0
        local _update_1 = kind
        flags[_update_1] = flags[_update_1] + 1
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
            local _update_2 = k
            flags[_update_2] = flags[_update_2] or v
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
      self.character_class_pattern = self.character_class_pattern or Ct(C("^") ^ -1 * (C(P("%") * S("adw")) + (C(1) * P("-") * C(1) / function(a, b)
        return tostring(a) .. tostring(b)
      end) + C(1)) ^ 1)
      local negate = false
      local plain_chars = { }
      local items = self.character_class_pattern:match(chars)
      local patterns
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #items do
          local _continue_0 = false
          repeat
            local item = items[_index_0]
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
      local g = P({
        "route",
        optional_literal = (1 - P(")") - V("chunk")) ^ 1 / make_lit,
        optional_route = Ct((V("chunk") + V("optional_literal")) ^ 1),
        optional = P("(") * V("optional_route") * P(")") / make_optional,
        literal = (1 - V("chunk")) ^ 1 / make_lit,
        chunk = var / make_var + splat / make_splat + V("optional"),
        route = Ct((V("chunk") + V("literal")) ^ 1)
      })
      return g / function(chunks)
        local pattern, flags = self:compile_chunks(chunks)
        return chunks, Ct(pattern) * -1, flags
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
      end
      if name then
        self.named_routes[name] = route
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
    route_precedence = function(self, flags)
      local p = 0
      if flags.var then
        p = p + flags.var
      end
      if flags.splat then
        p = p + (10 + (1 / flags.splat) * 10)
      end
      return p
    end,
    build = function(self)
      local by_precedence = { }
      local parsed_routes = { }
      local _list_0 = self.routes
      for _index_0 = 1, #_list_0 do
        local _des_0 = _list_0[_index_0]
        local path, responder, name
        path, responder, name = _des_0[1], _des_0[2], _des_0[3]
        local pattern, flags, chunks = self:build_route(path, responder, name)
        local p = self:route_precedence(flags)
        local _update_0 = p
        by_precedence[_update_0] = by_precedence[_update_0] or { }
        table.insert(by_precedence[p], pattern)
        if name then
          parsed_routes[name] = chunks
        end
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
      self.parsed_routes = parsed_routes
    end,
    build_route = function(self, path, responder, name)
      local chunks, pattern, flags = self.parser:parse(path)
      pattern = pattern / function(params)
        return params, responder, path, name
      end
      return pattern, flags, chunks
    end,
    fill_path = (function()
      local compile_chunks
      compile_chunks = function(buffer, chunks, get_var)
        local filled_vars = 0
        for _index_0 = 1, #chunks do
          local instruction = chunks[_index_0]
          local _exp_0 = instruction[1]
          if "literal" == _exp_0 then
            buffer[#buffer + 1] = instruction[2]
          elseif "var" == _exp_0 or "splat" == _exp_0 then
            local var_name
            if instruction[1] == "splat" then
              var_name = "splat"
            else
              var_name = instruction[2]
            end
            local var_value = get_var(var_name)
            if var_value ~= nil then
              filled_vars = filled_vars + 1
              buffer[#buffer + 1] = var_value
            end
          elseif "optional" == _exp_0 then
            local pos = #buffer
            local optional_filled = compile_chunks(buffer, instruction[2], get_var)
            if optional_filled == 0 then
              for i = #buffer, pos + 1, -1 do
                buffer[i] = nil
              end
            end
          else
            error("got unknown chunk type when compiling url: " .. tostring(instruction[1]))
          end
        end
        return filled_vars
      end
      return function(self, chunks, params, route_name)
        local get_var
        get_var = function(param_name)
          local val = params and params[param_name]
          if val == nil then
            return 
          end
          if "table" == type(val) then
            do
              local get_key = val.url_key
              if get_key then
                return get_key(val, route_name, param_name) or ""
              else
                local obj_name = val.__class and val.__class.__name or type(val)
                return error("lapis.router: attmpted to generate route parameter for object without 'url_key' method: " .. tostring(obj_name))
              end
            end
          else
            return val
          end
        end
        local b = { }
        compile_chunks(b, chunks, get_var)
        return table.concat(b)
      end
    end)(),
    url_for = function(self, name, params, query)
      if not (name) then
        return params
      end
      if not (self.p) then
        self:build()
      end
      local chunks = self.parsed_routes[name]
      if not (chunks) then
        error("lapis.router: There is no route named: " .. tostring(name))
      end
      local path = self:fill_path(chunks, params, name)
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
    match = function(self, route)
      if not (self.p) then
        self:build()
      end
      return self.p:match(route)
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
      self.parsed_routes = { }
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
