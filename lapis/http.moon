if ngx
  if ngx.config and ngx.config.is_console
    -- the "location capture" client is not compatible with resty
    require "lapis.nginx.resty_http"
  else
    require "lapis.nginx.http"
elseif package.loaded["lapis.running_server"] == "cqueues"
  require "http.compat.socket"
else
  require "socket.http"
