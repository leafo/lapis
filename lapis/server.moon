
current = ->
  return "nginx" if ngx
  "xavante"

make_static_handler = (root) ->
  =>
    import req, res from @
    req.relpath = @params.splat

    if current! == "xavante"
      handler = xavante.filehandler root
      handler req, res, root

    layout: false


serve_from_static = (root="static") ->
  handler = make_static_handler root
  =>
    @params.splat = @req.relpath
    handler @

{ :make_server, :make_static_handler, :serve_from_static, :current }

