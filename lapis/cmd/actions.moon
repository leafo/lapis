
import columnize, parse_flags, write_file_safe from require "lapis.cmd.util"

colors = require "ansicolors"

unpack = unpack or table.unpack

COMMANDS = {
  {
    name: "new"
    help: "Create a new Lapis project in the current directory"

    -- set up the argparse command
    configure: (command) =>
      with command
        \mutex(
          \flag "--cqueues", "Generate config for cqueues server"
          \flag "--nginx", "Generate config for nginx server"
        )
        \mutex(
          \flag "--lua", "Generate app template file in Lua"
          \flag "--moonscript --moon", "Generate app template file in MoonScript"
        )
        \flag "--etlua-config", "Use etlua for templmated configuration files (eg. nginx.conf)"
        \flag "--git", "Generate default .gitignore file"
        \flag "--tup", "Generate default Tupfile"

    (flags) =>
      server_actions = if flags.cqueues
        require "lapis.cmd.cqueues.actions"
      else
        require "lapis.cmd.nginx.actions"

      server_actions.new @, flags

      if flags.lua
        @write_file_safe "app.lua", require "lapis.cmd.templates.app_lua"
        @write_file_safe "models.lua", require "lapis.cmd.templates.models_lua"
      else
        @write_file_safe "app.moon", require "lapis.cmd.templates.app"
        @write_file_safe "models.moon", require "lapis.cmd.templates.models"

      if flags.git
        @write_file_safe ".gitignore", require("lapis.cmd.templates.gitignore") flags

      if flags.tup
        tup_files = require "lapis.cmd.templates.tup"
        for fname, content in pairs tup_files
          @write_file_safe fname, content
  }

  {
    name: "server"
    aliases: {"serve"}
    usage: "server [environment]"
    help: "build config and start server"

    (flags) =>
      environment = flags.environment
      @get_server_actions(environment).server @, flags, environment
  }

  {
    name: "build"
    usage: "build [environment]"
    help: "build config, send HUP if server running"
    context: { "nginx" }

    (flags) =>
      import write_config_for from require "lapis.cmd.nginx"
      write_config_for flags.environment

      import send_hup from require "lapis.cmd.nginx"
      pid = send_hup!
      print colors "%{green}HUP #{pid}" if pid
  }

  -- TODO: this is hidden comand
  {
    name: "hup"
    hidden: true
    help: "send HUP signal to running server"
    context: { "nginx" }

    =>
      import send_hup from require "lapis.cmd.nginx"
      pid = send_hup!
      if pid
        print colors "%{green}HUP #{pid}"
      else
        @fail_with_message "failed to find nginx process"
  }

  {
    name: "term"
    help: "sends TERM signal to shut down a running server"
    context: { "nginx" }

    =>
      import send_term from require "lapis.cmd.nginx"
      pid = send_term!
      if pid
        print colors "%{green}TERM #{pid}"
      else
        @fail_with_message "failed to find nginx process"

  }

  -- TODO: this is hidden
  {
    name: "signal"
    hidden: true
    help: "send arbitrary signal to running server"
    context: { "nginx" }

    (flags, signal) =>
      assert signal, "Missing signal"
      import send_signal from require "lapis.cmd.nginx"

      pid = send_signal signal
      if pid
        print colors "%{green}Sent #{signal} to #{pid}"
      else
        @fail_with_message "failed to find nginx process"
  }

  {
    name: "exec"
    usage: "exec <lua-string> [environment]"
    help: "execute Lua on the server"
    context: { "nginx" }

    (flags) =>
      import attach_server, get_pid from require "lapis.cmd.nginx"

      unless get_pid!
        print colors "%{green}Using temporary server..."

      server = attach_server flags.environment
      print server\exec flags.code
      server\detach!
  }

  {
    name: "migrate"
    usage: "migrate [environment]"
    help: "run migrations"

    (flags) =>
      env = require "lapis.environment"
      env.push flags.environment, show_queries: true

      migrations = require "lapis.db.migrations"
      migrations.run_migrations require("migrations"), nil, {
        transaction: switch flags.transaction
          when true
            "global"
          when "global", "individual"
            flags.transaction
          when nil
            nil
          else
            error "Got unknown --transaction setting"
      }

      env.pop!
  }

  {
    name: "generate"
    usage: "generate <template> [args...]"
    help: "generates a new file from template"

    (flags) =>
      {:template_name, :template_args} = flags

      local tpl, module_name

      pcall ->
        module_name = "generators.#{template_name}"
        tpl = require module_name

      unless tpl
        tpl = require "lapis.cmd.templates.#{template_name}"

      unless type(tpl) == "table"
        error "invalid generator `#{module_name or template_name}`, module must be table"

      writer = {
        write: (_, ...) -> assert @write_file_safe ...
        mod_to_path: (mod) =>
          mod\gsub "%.", "/"
      }

      if tpl.check_args
        tpl.check_args unpack template_args

      unless type(tpl.write) == "function"
        error "generator `#{module_name or }` is missing write function"

      tpl.write writer, unpack template_args
  }
}

class CommandRunner
  default_action: "help"

  new: =>
    @path = require "lapis.cmd.path"
    @path = @path\annotate!

  format_error: (msg) =>
    colors "%{bright red}Error:%{reset} #{msg}"

  fail_with_message: (msg) =>
    import running_in_test from require "lapis.spec"

    if running_in_test!
      error "Aborting: #{msg}"
    else
      print colors "%{bright}%{red}Aborting:%{reset} " .. msg
      os.exit 1

  write_file_safe: (file, content) =>
    colors = require "ansicolors"

    return nil, "file already exists: #{file}" if @path.exists file

    if prefix = file\match "^(.+)/[^/]+$"
      @path.mkdir prefix unless @path.exists prefix

    @path.write_file file, content
    true

  parse_args: (args) =>
    args = {i, a for i, a in pairs(args) when type(i) == "number" and i > 0}
    parser = require("lapis.cmd.argparser")

    if next(args) == nil
      args = { @default_action }

    parser\parse args

  execute: (args) =>
    args = @parse_args args
    action = @get_command args.command

    -- verify that we have suitable server install to run the environment
    if action.context
      assert @check_context args.environment, action.context

    fn = assert(action[1], "command `#{args.command}' not implemented")
    fn @, args

  execute_safe: (args) =>
    trace = false

    for v in *args
      trace = true if v == "--trace"

    import running_in_test from require "lapis.spec"

    if trace or running_in_test!
      return @execute args

    xpcall(
      -> @execute args
      (err) ->
        err = err\match("^.-:.-:.(.*)$") or err
        msg = colors "%{bright red}Error:%{reset} #{err}"
        print msg
        print " * Run with --trace to see traceback"
        print " * Report issues to https://github.com/leafo/lapis/issues"
        os.exit 1
    )

  get_server_type: (environment) =>
    config = require("lapis.config").get environment
    (assert config.server, "failed to get server type from config (did you set `server`?)")

  get_server_module: (environment) =>
    require "lapis.cmd.#{@get_server_type environment}"

  get_server_actions: (environment) =>
    require "lapis.cmd.#{@get_server_type environment}.actions"

  check_context: (environment, contexts) =>
    s = @get_server_module!

    for c in *contexts
      return true if c == s.type

    nil, "command not available for selected server (using #{s.type}, needs #{table.concat contexts, ", "})"

  get_command: (name) =>
    for k,v in ipairs COMMANDS
      return v if v.name == name

    -- no match, try loading command by module name
    local action
    pcall ->
      action = require "lapis.cmd.actions.#{name}"

    action

actions = CommandRunner!

{
  :actions
  get_action: actions\get_command
  execute: actions\execute_safe
}

