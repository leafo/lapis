
class AttachedServer
  start: (env, env_overrides) =>
    error "override me"

  detach: =>
    error "override me"

  status_tick: =>
    -- will be called on every tick to poll the server
    -- override to cherck if the server has crashed

  wait_until: (server_status="open") =>
    socket = require "socket"
    max_tries = 100
    sleep_for = 0.001

    start = socket.gettime!

    while true
      @status_tick!
      sock = socket.connect "127.0.0.1", (assert @port, "missing port")
      switch server_status
        when "open"
          if sock
            sock\close!
            break
        when "close"
          if sock
            sock\close!
          else
            break
        else
          error "don't know how to wait for #{server_status}"

      max_tries -= 1
      if max_tries == 0
        error "Timed out waiting for server to #{server_status} (#{socket.gettime! - start})"

      socket.sleep sleep_for
      sleep_for = math.min 0.1, sleep_for*2


  wait_until_ready: => @wait_until "open"
  wait_until_closed: => @wait_until "close"

{ :AttachedServer }
