
module "lapis.application", package.seeall

require "lapis.layout"
require "lapis.router"

import Router from lapis.router
import Layout from lapis.layout

export Application, Request

class Request
  new: (@app, @req, @res) =>
    @res.headers["Content-type"] = "text/html"
    @buffer = {} -- output buffer

  add_params: (params, name) =>
    self[name] = params
    for k,v in pairs params
      self[k] = v

  render: => table.concat @buffer

  write: (thing) =>
    switch type(thing)
      when "string"
        table.insert @buffer, thing
      when "table"
        @write part for part in *thing
      when "function"
        @write thing @buffer
      else
        error "Don't know how to write:", tostring(thing)

  _debug: =>
    @buffer = {
      "<html>", "req:", "<pre>"
      moon.dump @req
      "</pre>", "res:", "<pre>"
      moon.dump @res
      "</pre>", "</html>"
    }


class Application
  layout: Layout

  new: =>
    @router = Router!

    for path, handler in pairs @@__base
      t = type path
      if t == "table" or t == "string" and path\match "^/"
        @router\add_route path, @wrap_handler handler

  wrap_handler: (handler) =>
    (params, path, name, r) ->
      with r
        .route_name = name
        \add_params params, "url_params"
        out = handler r
        \write out if out

  dispatch: (req, res) =>
    r = Request self, req, res
    @router\resolve req.parsed_url.path, r
    res.content = r\render!
    res

  serve: =>

