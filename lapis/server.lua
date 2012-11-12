local current
current = function()
  if ngx then
    return "nginx"
  end
  return "xavante"
end
local make_static_handler
make_static_handler = function(root)
  return function(self)
    local req, res = self.req, self.res
    req.relpath = self.params.splat
    if current() == "xavante" then
      local handler = xavante.filehandler(root)
      handler(req, res, root)
    end
    return {
      layout = false
    }
  end
end
local serve_from_static
serve_from_static = function(root)
  if root == nil then
    root = "static"
  end
  local handler = make_static_handler(root)
  return function(self)
    self.params.splat = self.req.relpath
    return handler(self)
  end
end
return {
  make_server = make_server,
  make_static_handler = make_static_handler,
  serve_from_static = serve_from_static,
  current = current
}
