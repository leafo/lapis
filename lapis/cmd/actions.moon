
import columnize, parse_flags, write_file_safe from require "lapis.cmd.util"

colors = require "ansicolors"

unpack = unpack or table.unpack

COMMANDS = {
  {
    name: "new"
    help: "Create a new Lapis project in the current directory"

    -- set up the argparse command
    argparse: (command) ->
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
    help: "Rebuild configuration and send a reload signal to running server"

    argparse: (command) ->
      command\argument("environment")\args "?"

    (args) =>
      {:environment} = args
      @get_server_actions(environment).server @, args, environment
  }

  {
    name: "build"
    help: "Rebuild configuration and send a reload signal to running server"
    context: { "nginx" }

    argparse: (command) ->
      command\argument("environment")\args "?"

    (flags) =>
      import write_config_for from require "lapis.cmd.nginx"
      write_config_for flags.environment

      import send_hup from require "lapis.cmd.nginx"
      pid = send_hup!
      print colors "%{green}HUP #{pid}" if pid
  }

  {
    name: "hup"
    hidden: true
    help: "Send HUP signal to running server"
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
    help: "Sends TERM signal to shut down a running server"
    context: { "nginx" }

    =>
      import send_term from require "lapis.cmd.nginx"
      pid = send_term!
      if pid
        print colors "%{green}TERM #{pid}"
      else
        @fail_with_message "failed to find nginx process"

  }

  {
    name: "signal"
    hidden: true
    help: "Send arbitrary signal to running server"
    context: { "nginx" }

    argparse: (command) ->
      command\argument "signal", "Signal to send, eg. TERM, SIGHUP, etc."

    (args) =>
      {:signal} = args

      import send_signal from require "lapis.cmd.nginx"

      pid = send_signal signal
      if pid
        print colors "%{green}Sent #{signal} to #{pid}"
      else
        @fail_with_message "failed to find nginx process"
  }

  {
    name: "exec"
    help: "Execute Lua on the server"
    context: { "nginx" }

    argparse: (command) ->
      with command
        \argument "code", "String code to execute. Set - to read code from stdin"
        \mutex(
          -- TODO: add this
          -- \flag "--moonscript --moon", "Execute code as MoonScript"
          \flag "--lua", "Execute code as Lua"
        )

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
    help: "Run any outstanding migrations"

    argparse: (command) ->
      with command
        \argument("environment")\args "?"
        \option("--migrations-module", "Module to load for migrations")\argname("<module>")\default "migrations"
        \option("--transaction")\args("?")\choices({"global", "individual"})\action (args, name, val) ->
          -- flatten the table that's created from args("?")
          args[name] = val[next(val)] or "global"

    (args) =>
      env = require "lapis.environment"
      env.push args.environment, show_queries: true

      migrations = require "lapis.db.migrations"
      migrations.run_migrations require(args.migrations_module), nil, {
        transaction: args.transaction
      }

      env.pop!
  }

  {
    name: "generate"
    help: "Generates a new file in the current directory from template"

    argparse: (command) ->
      with command
        \argument("template_name", "Which template to load (eg. model, flow)")
        \argument("template_args", "Template arguments")\args("*")
        \mutex(
          \flag "--moonscript --moon", "Prefer to generate MoonScript file when appropriate"
          \flag "--lua", "Prefer to generate Lua file when appropriate"
        )


    (args) =>
      {:template_name, :template_args} = args

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

  {
    name: "_"
    help: "Excute third-party command from module lapis.cmd.actions._"

    argparse: (command) ->
      with command
        \handle_options false
        \argument("subcommand", "Which command module to load")
        \argument("args", "Arguments to command")\args("*")

    => error "This command is not implemented yet"
  }

  {
    name: "systemd"
    help: "Generate systemd service file"
    test_available: ->
      pcall -> require "lapis.cmd.actions.systemd"

    argparse: (command) ->
      with command
        \argument("sub_command", "Sub command to execute")\choices {"service"}
        \argument("environment", "Environment to create service file for")\args "?"
        \flag "--install", "Installs the service file to the system, requires sudo permission"

    => error "not yet"
  }

  {
    name: "annotate"
    help: "Annotate model files with schema information"
    test_available: ->
      pcall -> require "lapis.cmd.actions.annotate"

    argparse: (command) ->
      with command
        \argument("files", "Paths to model classes to annotate (eg. models/first.moon models/second.moon ...)")\args "+"

    => error "not yet"
  }
}

class CommandRunner
  default_action: "help"

  new: =>
    @path = require "lapis.cmd.path"
    @path = @path\annotate!

  build_parser: =>
    import default_environment from require "lapis.environment"
    import find_nginx from require "lapis.cmd.nginx"

    colors = require "ansicolors"
    argparse = require "argparse"

    lua_http_status_string = ->
      local str
      pcall ->
        str = colors "cqueues: %{bright}#{require("cqueues").VERSION}%{reset} lua-http: %{bright}#{require("http.version").version}%{reset}"

      str

    parser = argparse "lapis",
      table.concat {
        "Control & create web applications written with Lapis"
        colors "Lapis: %{bright}#{require "lapis.version"}"
        colors "Default environment: %{yellow}#{default_environment!}"
        if nginx = find_nginx!
          colors "OpenResty: %{bright}#{nginx}"
        else
          "No OpenResty installation found"

        if status = lua_http_status_string!
          status
        else
          "cqueues lua-http: not available"
      }, "\n"

    parser\command_target "command"
    parser\add_help_command!

    parser\option("--environment", "Override the default environment")\default default_environment!
    parser\flag "--trace", "Show full error trace if lapis command fails"

    for command_spec in *COMMANDS
      if command_spec.test_available
        continue unless command_spec.test_available!

      name = command_spec.name
      if command_spec.aliases
        name = "#{name} #{table.concat command_spec.aliases, " "}"

      command = parser\command name, command_spec.help

      if command_spec.hidden
        command\hidden true
      
      if type(command_spec.argparse) == "function"
        command_spec.argparse command

    parser

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
    parser = @build_parser!

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

