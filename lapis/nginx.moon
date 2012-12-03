
url = require "socket.url"
upload = require "resty.upload"
import escape_pattern, parse_content_disposition from require "lapis.util"

flatten_params = (t) ->
  {k, type(v) == "table" and v[#v] or v for k,v in pairs t}

parse_multipart = ->
  out = {}
  input = upload\new 8192

  current = { content: {} }
  while true
    t, res, err = input\read!
    switch t
      when "body"
        table.insert current.content, res
      when "header"
        name, value = unpack res
        if name == "Content-Disposition"
          if params = parse_content_disposition value
            for tuple in *params
              current[tuple[1]] = tuple[2]
        else
          current[name\lower!] = value
      when "part_end"
        current.content = table.concat current.content

        if current.name
          if current["content-type"] -- a file
            out[current.name] = current
          else
            out[current.name] = current.content

        current = { content: {} }

    break if t == "eof"

  out

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

  params_post: (t) ->
    -- parse multipart if required
    if (t.headers["content-type"] or "")\match escape_pattern "multipart/form-data"
      parse_multipart!
    else
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
  ngx.status = res.status if res.status
  ngx.say res.content if res.content
  res

debug = (thing) ->
  require "moon"
  ngx.say "debug <pre>"
  ngx.say moon.dump thing
  ngx.say "<pre>"

{ :build_request, :build_response, :dispatch, :debug }


