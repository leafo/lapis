if ngx then
  if ngx.config and ngx.config.is_console then
    return require("lapis.nginx.resty_http")
  else
    return require("lapis.nginx.http")
  end
elseif package.loaded["lapis.running_server"] == "cqueues" then
  return require("http.compat.socket")
else
  return require("socket.http")
end
