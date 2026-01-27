local lapis_config = require("lapis.config")
local increment_perf
increment_perf = require("lapis.nginx.context").increment_perf
local wrap_source
wrap_source = function(source)
  return function()
    local chunk, err = source()
    if err then
      ngx.log(ngx.ERR, "source error: ", err)
      return nil
    end
    return chunk
  end
end
local request
request = function(url, str_body)
  local http = require("resty.http")
  local ltn12 = require("ltn12")
  local config = lapis_config.get()
  local start_time
  if config.measure_performance then
    ngx.update_time()
    start_time = ngx.now()
  end
  local return_res_body
  local req
  if type(url) == "table" then
    req = url
  else
    return_res_body = true
    req = {
      url = url,
      source = str_body and ltn12.source.string(str_body),
      headers = str_body and {
        ["Content-type"] = "application/x-www-form-urlencoded"
      }
    }
  end
  req.method = req.method or (req.source and "POST" or "GET")
  local httpc = http.new()
  local res, err = httpc:request_uri(req.url, {
    method = req.method,
    headers = req.headers,
    body = req.source and wrap_source(req.source),
    ssl_verify = true
  })
  if not (res) then
    error("resty.http request failed: " .. tostring(err))
  end
  local out
  if return_res_body then
    out = res.body
  else
    if req.sink then
      ltn12.pump.all(ltn12.source.string(res.body), req.sink)
    end
    out = 1
  end
  if start_time then
    ngx.update_time()
    increment_perf("http_count", 1)
    increment_perf("http_time", ngx.now() - start_time)
  end
  return out, res.status, res.headers
end
return {
  request = request
}
