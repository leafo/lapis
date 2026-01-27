
-- This implements a basic LuaSocket's http.request interface using lua-resty-http.
-- Dependencies:
--   luarocks install lua-resty-http
--   luarocks install lua-resty-openssl
--
-- Usage:
--   http = require "lapis.nginx.resty_http"
--   body, status, headers = http.request("http://example.com")
--
-- From resty:
--   resty --http-conf "lua_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt; lua_ssl_verify_depth 2;" -e 'print(require("lapis.http").request("https://leafo.net"))'

lapis_config = require "lapis.config"

import increment_perf from require "lapis.nginx.context"

-- convert ltn12 source to a function that resty.http can use without swalling up any error messages
wrap_source = (source) ->
  ->
    chunk, err = source!
    if err
      ngx.log ngx.ERR, "source error: ", err
      return nil
    chunk

---Make an HTTP request using lua-resty-http
---@param url string|table URL string or request table with url, method, source, sink, headers fields
---@param str_body string? Request body for simple POST requests
---@return string|number body Response body (or 1 if sink was provided)
---@return number status HTTP status code
---@return table headers Response headers
request = (url, str_body) ->
  http = require "resty.http"
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

  httpc = http.new!
  -- TODO: if source iterator returns an error, resty.http treats it as end of stream and does not surface the error
  res, err = httpc\request_uri req.url, {
    method: req.method
    headers: req.headers
    body: req.source and wrap_source req.source
    ssl_verify: true
  }

  unless res
    error "resty.http request failed: #{err}"

  out = if return_res_body
    res.body
  else
    -- TODO: support streaming response body to sink, would need to use lower level API
    if req.sink
      ltn12.pump.all ltn12.source.string(res.body), req.sink
    1

  if start_time
    ngx.update_time!
    increment_perf "http_count", 1
    increment_perf "http_time", ngx.now! - start_time

  out, res.status, res.headers

{ :request }
