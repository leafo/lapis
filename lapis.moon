-- todo: splats in routes (*)
-- Cmt conditions on routes
-- pattern classes
--    :something[num] *[slug]

import p from require "moon"
import insert from table

require "lpeg"

import R, S, V, P from lpeg
import C, Ct, Cmt, Cg, Cb, Cc from lpeg

reduce = (items, fn) ->
  return items[1] if #items == 1
  left = fn items[1], items[2]
  for i = 3, #items
    left = fn left, items[i]
  left

class Router

  alpha = R("az", "AZ", "__")
  alpha_num = alpha + R("09")
  slug = (alpha_num + S("-")) ^ 1

  make_var = (str) ->
    name = str\sub 2
    Cg slug, name

  make_lit = (str) -> P(str)

  symbol = P":" * alpha * alpha_num^0
  chunk = (1 - symbol)^1 / make_lit + symbol / make_var

  @route_grammar = Ct(chunk^1) / (parts) ->
    patt = reduce parts, (a,b) -> a * b
    Ct patt

  new: =>
    @routes = {}
    @named_routes = {}

  add_route: (route, responder) =>
    @_build = false
    if type(route) == "table"
      name = next route
      route = route[name]
      @named_routes[name] = route

    insert @routes, { route, responder }

  build: =>
    @p = reduce [@build_route unpack r for r in *@routes], (a, b) -> a + b
  
  build_route: (path, responder) =>
    @@route_grammar\match(path) * -1 / (params) ->
      print "matched", path
      p params

  url_for: (name, params) ->
    error "TODO"

  resolve: (route) =>
    @build! unless @_built
    @p\match route

r = Router!

with r
  \add_route home: "/"
  \add_route dad: "/dad"
  \add_route user: "/user/:id"

r\resolve "/user/34343"

-- p r\url_for "user", id: 2323

