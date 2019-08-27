
-- This implements LuaSocket's http.request on top of a proxy_pass within
-- nginx.
--
-- Add the following location to your server:
--
-- location /proxy {
--     internal;
--     rewrite_by_lua "
--       local req = ngx.req
--
--       for k,v in pairs(req.get_headers()) do
--         if k ~= 'content-length' then
--           req.clear_header(k)
--         end
--       end
--
--       if ngx.ctx.headers then
--         for k,v in pairs(ngx.ctx.headers) do
--           req.set_header(k, v)
--         end
--       end
--     ";
--
--     resolver 8.8.8.8;
--     proxy_http_version 1.1;
--     proxy_pass $_url;
-- }
--
--
-- Add the following to your default location:
--
-- set $_url "";
--

lapis_config = require "lapis.config"

import increment_perf from require "lapis.nginx.context"

proxy_location = "/proxy"

-- methods.get -> ngx.HTTP_GET
methods = setmetatable {}, __index: (name) =>
  id = ngx["HTTP_#{name\upper!}"]
  @[name] = id
  id

set_proxy_location = (loc) -> proxy_location = loc

import encode_query_string from require "lapis.util"

-- a simple http interface that doesn't use ltn12
simple = (req, body) ->
  config = lapis_config.get!
  start_time = if config.measure_performance
    ngx.update_time!
    ngx.now!

  if type(req) == "string"
    req = { url: req }

  if body
    req.method = "POST"
    req.body = body

  if type(req.body) == "table"
    req.body = encode_query_string req.body
    req.headers or= {}
    req.headers["Content-type"] = "application/x-www-form-urlencoded"

  -- ensure the url has trailing / so nginx overwites path
  unless req.url\match "//.-/"
    req.url ..= "/"

  res = ngx.location.capture proxy_location, {
    method: methods[req.method or "GET"]
    body: req.body
    ctx: {
      headers: req.headers
    }
    vars: { _url: req.url }
  }

  if start_time
    ngx.update_time!
    increment_perf "http_count", 1
    increment_perf "http_time", ngx.now! - start_time

  res.body, res.status, res.header

request = (url, str_body) ->
  ltn12 = require "ltn12"

  config = lapis_config.get!
  start_time = if config.measure_performance
    ngx.update_time!
    ngx.now!

  local return_res_body
  req = if type(url) == "table"
    url
  else
    return_res_body = true
    {
      :url
      source: str_body and ltn12.source.string str_body
      headers: str_body and {
        "Content-type": "application/x-www-form-urlencoded"
      }
    }

  req.method or= req.source and "POST" or "GET"

  body = if req.source
    buff = {}
    sink = ltn12.sink.table buff
    ltn12.pump.all req.source, sink
    table.concat buff

  -- ensure the url has trailing / so nginx overwites path
  unless req.url\match "//.-/"
    req.url ..= "/"

  res = ngx.location.capture proxy_location, {
    method: methods[req.method]
    body: body
    ctx: {
      headers: req.headers
    }
    vars: {
      _url: req.url
    }
  }

  out = if return_res_body
    res.body
  else
    if req.sink
      ltn12.pump.all ltn12.source.string(res.body), req.sink
    1

  if start_time
    ngx.update_time!
    increment_perf "http_count", 1
    increment_perf "http_time", ngx.now! - start_time

  out, res.status, res.header

ngx_replace_headers = (new_headers=nil) ->
  import req from ngx
  new_headers or= ngx.ctx.headers

  for k,v in pairs req.get_headers!
    if k != 'content-length' then
        req.clear_header k

  if new_headers
    for k,v in pairs new_headers
      req.set_header k, v


{ :request, :simple, :set_proxy_location, :ngx_replace_headers, :methods }

