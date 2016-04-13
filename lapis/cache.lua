if ngx then
  return require("lapis.nginx.cache")
else
  return error("cache only supported in nginx")
end
