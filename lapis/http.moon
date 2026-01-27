if ngx
  require "lapis.nginx.http"
elseif package.loaded["lapis.running_server"] == "cqueues"
  require "http.compat.socket"
else
  require "socket.http"
