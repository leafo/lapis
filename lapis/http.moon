if ngx
  require "lapis.nginx.http"
elseif pcall require, "http.compat.socket"
  require "http.compat.socket"
else
  require "socket.http"
