import escape_pattern, parse_content_disposition, build_url from require "lapis.util"
import run_after_dispatch from require "lapis.nginx.context"
lapis_config = require "lapis.config"

flatten_params = (t) ->
  {k, type(v) == "table" and v[#v] or v for k,v in pairs t}

parse_multipart = ->
  out = {}
  upload = require "resty.upload"

  input, err = upload\new 8192
  return nil, err unless input

  input\set_timeout 1000 -- 1 sec

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
      when "eof"
        break
      else
        return nil, err or "failed to read upload"

  out

ngx_req = {
  headers: -> ngx.req.get_headers!
  cmd_mth: -> ngx.var.request_method
  cmd_url: ->  ngx.var.request_uri

  relpath: (t) -> t.parsed_url.path
  scheme: -> ngx.var.scheme
  port: -> ngx.var.server_port
  srv: -> ngx.var.server_addr
  remote_addr: -> ngx.var.remote_addr
  referer: -> ngx.var.http_referer or ""

  parsed_url: (t) ->
    uri = ngx.var.request_uri
    uri = uri\match("(.-)%?") or uri
    host_header = ngx.var.http_host

    {
      scheme: ngx.var.scheme
      path: uri
      host: ngx.var.host
      port: host_header and host_header\match ":(%d+)$"
      query: ngx.var.args
    }

  built_url: (t) ->
    build_url t.parsed_url

  params_post: (t) ->
    content_type = t.headers["content-type"] or ""
    content_type = "" unless type(content_type) == "string"
    content_type = content_type\lower!

    params = if content_type\match escape_pattern "multipart/form-data"
      parse_multipart!
    elseif content_type\match escape_pattern "application/x-www-form-urlencoded"
      ngx.req.read_body!

      args = if max = lapis_config.get!.max_request_args
        ngx.req.get_post_args max
      else
        ngx.req.get_post_args!

      flatten_params args

    params or {}

  params_get: ->
    args = if max = lapis_config.get!.max_request_args
      ngx.req.get_uri_args max
    else
      ngx.req.get_uri_args!

    flatten_params args
}

lazy_tbl = (tbl, index) ->
  setmetatable tbl, {
    __index: (key) =>
      fn = index[key]
      if fn
        with res = fn @
          @[key] = res
  }


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
          @headers[k] = old
        else
          @headers[k] = {old, v}

    headers: ngx.header
  }

dispatch = (app) ->
  res = build_response!
  app\dispatch res.req, res
  ngx.status = res.status if res.status
  ngx.print res.content if res.content

  run_after_dispatch!
  res

{ :build_request, :build_response, :dispatch }


