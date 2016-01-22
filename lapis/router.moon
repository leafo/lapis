
-- todo: splats in routes (*)
-- Cmt conditions on routes
-- pattern classes
--    :something[num] *[slug]

import insert from table

lpeg = require "lpeg"

import R, S, V, P from lpeg
import C, Cs, Ct, Cmt, Cg, Cb, Cc from lpeg

import encode_query_string from require "lapis.util"

reduce = (items, fn) ->
  count = #items
  error "reducing 0 item list" if count == 0
  return items[1] if count == 1
  left = fn items[1], items[2]
  for i = 3, count
    left = fn left, items[i]
  left

route_precedence = (flags) ->
  p = 0

  if flags.var
    p += 1

  if flags.splat
    p += 2

  p

class RouteParser
  new: =>
    @grammar = @build_grammar!

  -- returns an lpeg patternt that matches route, along with table of flags
  parse: (route) =>
    @grammar\match route

  compile_exclude: (current_p, chunks, k=1) =>
    local out
    for {kind, value, val_params} in *chunks[k,]
      switch kind
        when "literal"
          if out
            out += value
          else
            out = value
          break
        when "optional"
          p = route_precedence val_params
          continue if current_p < p
          if out
            out += value
          else
            out = value
        else
          break

    out

  compile_chunks: (chunks, exclude=nil) =>
    local patt
    flags = {}

    for i=#chunks,1,-1
      chunk = chunks[i]
      {kind, value, val_params} = chunk
      flags[kind] = true

      chunk_pattern = switch kind
        when "splat"
          inside = P 1
          inside -= exclude if exclude
          exclude = nil
          Cg inside^1, "splat"
        when "var"
          char = val_params and @compile_character_class(val_params) or P 1

          inside = char - "/"
          inside -= exclude if exclude
          exclude = nil
          Cg inside^1, value
        when "literal"
          exclude = P value
          P value
        when "optional"
          inner, inner_flags, inner_exclude = @compile_chunks value, exclude

          for k,v in pairs inner_flags
            flags[k] or= v

          if inner_exclude
            if exclude
              exclude = inner_exclude + exclude
            else
              exclude = inner_exclude

          inner^-1
        else
          error "unknown node: #{kind}"

      patt = if patt
        chunk_pattern * patt
      else
        chunk_pattern

    patt, flags, exclude

  -- convert character class, like %d to an lpeg pattern
  compile_character_class: (chars) =>
    @character_class_pattern or= Ct C("^")^-1 * C(
      P"%" * S"adw" +
      (C(1) * P"-" * C(1) / (a, b) -> "#{a}#{b}") +
      1
    )^1

    negate = false
    plain_chars = {}
    patterns = for item in *@character_class_pattern\match chars
      switch item
        when "^"
          negate = true
          continue
        when "%a"
          R "az", "AZ"
        when "%d"
          R "09"
        when "%w"
          R "09", "az", "AZ"
        else
          if #item == 2
            R item
          else
            table.insert plain_chars, item
            continue

    if next plain_chars
      table.insert patterns, S table.concat plain_chars

    local out
    for p in *patterns
      if out
        out += p
      else
        out = p

    if negate
      out = 1 - out

    out or P -1

  build_grammar: =>
    alpha = R("az", "AZ", "__")
    alpha_num = alpha + R("09")

    make_var = (str, char_class) -> { "var", str\sub(2), char_class }
    make_splat = -> { "splat" }
    make_lit = (str) -> { "literal", str }
    make_optional = (children) -> { "optional", children }

    splat = P"*"
    var = P":" * alpha * alpha_num^0

    @var = var
    @splat = splat

    var = C(var) * (P"[" * C((1 - P"]")^1) * P"]")^-1

    chunk = var / make_var + splat / make_splat
    chunk = (1 - chunk)^1 / make_lit + chunk

    compile_chunks = @\compile_chunks

    g = P {
      "route"
      optional_literal: (1 - P")" - V"chunk")^1 / make_lit
      optional_route: Ct((V"chunk" + V"optional_literal")^1)
      optional: P"(" * V"optional_route" * P")" / make_optional

      literal: (1 - V"chunk")^1 / make_lit
      chunk: var / make_var + splat / make_splat + V"optional"

      route: Ct((V"chunk" + V"literal")^1)
    }

    g / @\compile_chunks / (p, f) -> Ct(p) * -1, f


class Router
  new: =>
    @routes = {}
    @named_routes = {}
    @parser = RouteParser!

  add_route: (route, responder) =>
    @p = nil
    name = nil
    if type(route) == "table"
      name = next route
      route = route[name]

      -- keep existing route
      unless @named_routes[name]
        @named_routes[name] = route

    insert @routes, { route, responder, name }

  default_route: (route) =>
    error "failed to find route: " .. route

  build: =>
    by_precedence = {}

    for r in *@routes
      pattern, flags = @build_route unpack r
      p = route_precedence flags
      by_precedence[p] or= {}
      table.insert by_precedence[p], pattern

    precedences = [k for k in pairs by_precedence]
    table.sort precedences

    @p = nil
    for p in *precedences
      for pattern in *by_precedence[p]
        if @p
          @p += pattern
        else
          @p = pattern

    @p or= P -1
  
  build_route: (path, responder, name) =>
    pattern, flags = @parser\parse path
    pattern = pattern / (params) ->
      params, responder, path, name

    pattern, flags

  fill_path: (path, params={}, route_name) =>
    replace = (s) ->
      param_name = s\sub 2
      if val = params[param_name]
        if "table" == type val
          if get_key = val.url_key
            val = get_key(val, route_name, param_name) or ""
          else
            obj_name = val.__class and val.__class.__name or type(val)
            error "Don't know how to serialize object for url: #{obj_name}"
        val
      else
        ""

    patt = Cs (
      @parser.var / replace +
      @parser.splat / (params.splat or "") +
      1
    )^0

    patt\match(path)

  url_for: (name, params, query) =>
    return params unless name
    path = assert @named_routes[name], "Missing route named #{name}"
    path = @fill_path path, params, name

    if query
      if type(query) == "table"
        query = encode_query_string query

      if query != ""
        path ..= "?" .. query
    path

  resolve: (route, ...) =>
    @build! unless @p
    params, responder, path, name = @p\match route
    if params and responder
      responder params, path, name, ...
    else
      @default_route route, params, path, name

{ :Router, :RouteParser }

