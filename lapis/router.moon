
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

class Router
  alpha = R("az", "AZ", "__")
  alpha_num = alpha + R("09")
  slug = (P(1) - "/") ^ 1

  make_var = (str) ->
    name = str\sub 2
    {
      "var"
      Cg slug, name
    }

  make_splat = ->
    {
      "splat"
      Cg P(1)^1, "splat"
    }

  make_lit = (str) ->
    {
      "literal"
      P str
    }

  splat = P"*"
  var = P":" * alpha * alpha_num^0

  chunk = var / make_var + splat / make_splat
  chunk = (1 - chunk)^1 / make_lit + chunk

  @route_grammar = Ct(chunk^1) / (parts) ->
    patt = nil
    flags = {}
    for {t, part} in *parts
      flags[t] = true
      patt = if patt
        patt * part
      else
        part

    Ct(patt), flags

  new: =>
    @routes = {}
    @named_routes = {}

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
    pattern, flags = @@route_grammar\match(path)
    pattern = pattern * -1 / (params) ->
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

    patt = Cs (var / replace + 1)^0
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

{ :Router }

