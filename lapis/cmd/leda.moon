config = require 'lapis.config'
path = require "lapis.cmd.path"

local leda

class Leda
  paths: {
    "/usr/local/bin"
    "/usr/bin"
  }

  find_bin: =>
    return @bin if @bin

    bin = "leda"
    paths = [p for p in *@paths]
    table.insert paths, os.getenv "LAPIS_LEDA"

    for to_check in *paths
      to_check ..= "/#{bin}"

      if path.exists to_check
        @bin = to_check
        return @bin

    nil, "failed to find leda installation"

  start: (environment) =>
    assert @find_bin!

    port = config.get!.port
    host = config.get!.host or 'localhost'

    print "starting server on #{host}:#{port} in environment #{environment}. Press Ctrl-C to exit"

    env = ""
    if environment == 'development'
      env = "LEDA_DEBUG=1"

    execute = "#{env} #{@bin} --execute='require(\"lapis\").serve(\"app\")'"

    os.execute execute

leda = Leda!

find_leda = ->
  leda\find_bin!

start_leda = (environment) ->
  leda\start environment

{ :find_leda, :start_leda }

