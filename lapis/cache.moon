if ngx
	require "lapis.nginx.cache"
else
	error "cache only supported in nginx"
