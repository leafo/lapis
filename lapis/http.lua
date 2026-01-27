if ngx then
  return require("lapis.nginx.http")
elseif package.loaded["lapis.running_server"] == "cqueues" then
  return require("http.compat.socket")
else
  return require("socket.http")
end
