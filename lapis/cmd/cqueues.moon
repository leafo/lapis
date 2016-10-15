start_server =  (app) ->
  config = require("lapis.config").get!
  http_server = require "http.server"
  import dispatch from require "lapis.cqueues"

  server = http_server.listen {
    host: "127.0.0.1"
    port: assert config.port, "missing server port"

    onstream: (stream) =>
      dispatch app, @, stream

    onerror: (context, op, err, errno) =>
      msg = op .. " on " .. tostring(context) .. " failed"
      if err
        msg = msg .. ": " .. tostring(err)

      assert io.stderr\write msg, "\n"
  }

  bound_port = select 3, server\localname!
  print "Listening on #{bound_port}\n"
  assert server\loop!

{
  type: "cqueues"
  :start_server
}
