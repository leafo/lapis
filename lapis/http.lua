if ngx then
  return require("lapis.nginx.http")
elseif pcall(require, "http.compat.socket") then
  return require("http.compat.socket")
else
  return require("socket.http")
end
