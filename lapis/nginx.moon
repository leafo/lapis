
url = require "socket.url"

flatten_params = (t) ->
  {k, type(v) == "table" and v[#v] or v for k,v in pairs t}

ngx_req = {
  headers: -> ngx.req.get_headers!
  cmd_mth: -> ngx.var.request_method
  cmd_url: -> ngx.var.request_uri
  relpath: -> url.unescape ngx.var.uri
  scheme: -> ngx.var.scheme
  port: -> ngx.var.server_port
  srv: -> ngx.var.server_addr
  parsed_url: (t) ->
    url.parse "#{t.scheme}://#{ngx.var.http_host}#{t.cmd_url}"
  built_url: (t) ->
    url.build t.parsed_url

  params_post: ->
    ngx.req.read_body!
    flatten_params ngx.req.get_post_args!

  params_get: ->
    flatten_params ngx.req.get_uri_args!
}

lazy_tbl = (tbl, index) ->
  setmetatable tbl, {
    __index: (key) =>
      fn = index[key]
      if fn
        with res = fn @
          @[key] = res
  }


-- this gives us a table that looks like the request that we get in xavante
-- all the properties are evaluated lazily unless unlazy is true
build_request = (unlazy=false) ->
  with t = lazy_tbl {}, ngx_req
    if unlazy
      for k in pairs ngx_req
        t[k]

build_response = ->
  {
    req: build_request!
    add_header: (k, v) =>
      old = @headers[k]
      switch type old
        when "nil"
          @headers[k] = v
        when "table"
          old[#old + 1] = v
        else
          @headers[k] = {old, v}

    headers: ngx.header
  }

dispatch = (app) ->
  res = build_response!
  app\dispatch res.req, res
  ngx.say res.content
  res

{ :build_request, :build_response, :dispatch }


