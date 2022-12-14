
-- todo: splats in routes (*)
-- Cmt conditions on routes
-- pattern classes
--    :something[num] *[slug]

-- A router takes a list of routes and their callbacks and generates two lpeg
-- patterns:


import insert, concat from table
unpack = unpack or table.unpack

lpeg = require "lpeg"

import R, S, V, P from lpeg
import C, Cs, Ct, Cmt, Cg, Cb, Cc from lpeg

import encode_query_string from require "lapis.util"

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
          p = @route_precedence val_params
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
      flags[kind] or= 0
      flags[kind] += 1

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
    @character_class_pattern or= Ct C("^")^-1 * (
      C(P"%" * S"adw") +
      (C(1) * P"-" * C(1) / (a, b) -> "#{a}#{b}") +
      C(1)
    )^1

    negate = false
    plain_chars = {}
    items = @character_class_pattern\match chars

    patterns = for item in *items
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
    var = C(var) * (P"[" * C((1 - P"]")^1) * P"]")^-1

    @var = var
    @splat = splat

    chunk = var / make_var + splat / make_splat
    chunk = (1 - chunk)^1 / make_lit + chunk

    g = P {
      "route"
      optional_literal: (1 - P")" - V"chunk")^1 / make_lit
      optional_route: Ct((V"chunk" + V"optional_literal")^1)
      optional: P"(" * V"optional_route" * P")" / make_optional

      literal: (1 - V"chunk")^1 / make_lit
      chunk: var / make_var + splat / make_splat + V"optional"

      route: Ct((V"chunk" + V"literal")^1)
    }

    g / (chunks) ->
      pattern, flags = @compile_chunks chunks
      chunks, Ct(pattern) * -1, flags


class Router
  new: =>
    @routes = {}
    @named_routes = {} -- maps route_name -> route pattern, created when routes are added
    @parsed_routes = {} -- maps route_name -> parsed route (for url generation)
    @parser = RouteParser!

  add_route: (route, responder) =>
    @p = nil
    name = nil

    if type(route) == "table"
      name = next route
      route = route[name]

    if name
      @named_routes[name] = route

    insert @routes, { route, responder, name }

  -- default_route represents a responder that is used when a route can not be matched
  default_route: (route) =>
    error "failed to find route: " .. route

  route_precedence: (flags) =>
    p = 0

    if flags.var
      p += flags.var

    if flags.splat
      p += 10 + (1 / flags.splat) * 10

    p

  build: =>
    by_precedence = {}
    parsed_routes = {}

    for {path, responder, name} in *@routes
      pattern, flags, chunks = @build_route path, responder, name
      p = @route_precedence flags
      by_precedence[p] or= {}
      table.insert by_precedence[p], pattern

      if name -- stored the parsed path by name to allow for URL generation
        parsed_routes[name] = chunks

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
    @parsed_routes = parsed_routes
  
  build_route: (path, responder, name) =>
    chunks, pattern, flags = @parser\parse path

    pattern = pattern / (params) ->
      params, responder, path, name

    pattern, flags, chunks

  fill_path: do
    compile_chunks = (buffer, chunks, get_var) ->
      filled_vars = 0

      for instruction in *chunks
        switch instruction[1]
          when "literal"
            buffer[#buffer + 1] = instruction[2]
          when "var", "splat"
            var_name = if instruction[1] == "splat"
              "splat"
            else
              instruction[2]

            var_value = get_var var_name

            if var_value != nil
              filled_vars += 1
              buffer[#buffer +  1] = var_value
          when "optional"
            pos = #buffer
            optional_filled = compile_chunks buffer, instruction[2], get_var

            if optional_filled == 0
              -- remove anything written
              for i=#buffer,pos+1,-1
                buffer[i] = nil

          else
            error "got unknown chunk type when compiling url: #{instruction[1]}"

      filled_vars

    (chunks, params, route_name) =>
      get_var = (param_name) ->
        val = params and params[param_name]
        return if val == nil

        if "table" == type val
          if get_key = val.url_key
            get_key(val, route_name, param_name) or ""
          else
            obj_name = val.__class and val.__class.__name or type(val)
            error "lapis.router: attmpted to generate route parameter for object without 'url_key' method: #{obj_name}"
        else
          val

      b = {}
      compile_chunks b, chunks, get_var
      table.concat b

  url_for: (name, params, query) =>
    return params unless name -- a nil route name is a pass through (TODO: should this live in Request.url_for instead)

    @build! unless @p

    chunks = @parsed_routes[name]
    unless chunks
      error "lapis.router: There is no route named: #{name}"

    path = @fill_path chunks, params, name

    if query
      if type(query) == "table"
        query = encode_query_string query

      if query != ""
        path ..= "?" .. query

    path

  match: (route) =>
    @build! unless @p
    @p\match route

  resolve: (route, ...) =>
    @build! unless @p
    params, responder, path, name = @p\match route
    if params and responder
      responder params, path, name, ...
    else
      @default_route route, params, path, name

{ :Router, :RouteParser }

