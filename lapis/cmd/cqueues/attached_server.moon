

import to_json from require "lapis.util"
import AttachedServer from require "lapis.cmd.attached_server"

class CqueuesAttachedServer extends AttachedServer
  start: (env, overrides) =>
    thread = require "cqueues.thread"
    @port = overrides and overrides.port or require("lapis.config").get(env).port

    @current_thread, @thread_socket = assert thread.start(
      (sock, env, overrides using nil) ->
        import from_json from require "lapis.util"
        import push, pop from require "lapis.environment"
        import start_server from require "lapis.cmd.cqueues"

        overrides = from_json overrides
        overrides = nil unless next overrides

        push env, overrides

        config = require("lapis.config").get!
        app_module = config.app_class or "app"
        start_server app_module

      env, to_json overrides or {}

    )

    @wait_until_ready!

  detach: =>


{ AttachedServer: CqueuesAttachedServer }
