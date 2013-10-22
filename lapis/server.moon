
current = ->
  return "nginx" if ngx
  error "can't find ngx"

{ :current }

