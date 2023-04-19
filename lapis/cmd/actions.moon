
import parse_flags from require "lapis.cmd.util"

colors = require "ansicolors"

unpack = unpack or table.unpack

default_language = ->
  if f = io.open "config.moon"
    f\close!
    "moonscript"
  else
    "lua"

add_environment_argument = (command, summary) ->
  with command\argument("environment", summary)
    \args("?")
    \target "_environment" -- needs to be different to avoid niling --environment
    \action (args, name, val) ->
      if val
        if args.environment
          error "You tried to set the environment twice. Use either --environment or the environment argument, not both"
        args.environment = val

-- custom_action provides a top level command for triggered a third-party
-- action, eg for lapis-annotate and lapis-systemd
custom_action = (t) ->
  t.test_available = ->
    pcall -> require "lapis.cmd.actions.#{t.name}"

  t.argparse = (command) ->
    with command
      \handle_options false
      \argument("sub_command_args", "Arguments to command")\argname("<args>")\args("*")

  t[1] = (args) =>
    action = require "lapis.cmd.actions.#{t.name}"
    assert action.argparser, "Your lapis-#{t.name} module is too out of date for this version of Lapis, please update it"
    parse_args = action.argparser!
    action[1] @, parse_args\parse(args.sub_command_args), args

  t

COMMANDS = {
  {
    name: "new"
    help: "Create a new Lapis project in the current directory"

    -- set up the argparse command
    argparse: (command) ->
      with command
        \mutex(
          \flag "--nginx", "Generate config for nginx server (default)"
          \flag "--cqueues", "Generate config for cqueues server"
        )
        \mutex(
          \flag "--lua", "Generate app template file in Lua (defaul)"
          \flag "--moonscript --moon", "Generate app template file in MoonScript"
        )
        \flag "--etlua-config", "Use etlua for templated configuration files (eg. nginx.conf)"
        \flag "--git", "Generate default .gitignore file"
        \flag "--tup", "Generate default Tupfile"
        \flag "--rockspec", "Generate a rockspec file for managing dependencies"

        \flag "--force", "Bypass errors when detecting functional server environment"

    (args) =>
      server = if args.cqueues
        "cqueues"
      else
        "nginx"

      server_actions = require "lapis.cmd.#{server}.actions"

      language = if args.lua
        "lua"
      elseif args.moonscript
        "moonscript"
      else
        default_language!

      template_flags = { "--#{language}" }

      server_actions.new @, args, template_flags
      @execute {"generate", "application", unpack template_flags }
      @execute {"generate", "models", unpack template_flags }

      if args.git
        gitignore_flags = { "--#{language}", "--#{server}" }

        if args.tup
          table.insert gitignore_flags, "--tup"

        @execute {"generate", "gitignore", unpack gitignore_flags }

      if args.tup
        @execute {"generate", "tupfile" }

      if args.rockspec
        rockspec_flags = {}
        if language == "moonscript"
          table.insert rockspec_flags, "--moonscript"

        if server == "cqueues"
          table.insert rockspec_flags, "--cqueues"

        @execute {"generate", "rockspec", unpack rockspec_flags }
  }

  {
    name: "server"
    aliases: {"serve"}
    help: "Start the server from the current directory"

    argparse: (command) ->
      add_environment_argument command

    (args) =>
      @get_server_actions(args.environment).server @, args
  }

  {
    name: "build"
    help: "Rebuild configuration and send a reload signal to running server"
    context: { "nginx" }

    argparse: (command) ->
      add_environment_argument command

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
      command\argument "signal", "Signal to send, eg. TERM, HUP, etc."

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
    aliases: {"execute"}
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
      add_environment_argument command
      with command
        \option("--migrations-module", "Module to load for migrations")\argname("<module>")\default "migrations"
        \flag("--dry-run", "Immediately roll back after appyling migrations. Forces migrations to run in a transaction")
        \option("--transaction")\args("?")\choices({"global", "individual"})\action (args, name, val) ->
          -- flatten the table that's created from args("?")
          args[name] = val[next(val)] or "global"

    (args) =>
      env = require "lapis.environment"
      env.push args.environment, show_queries: true

      print colors "%{bright yellow}Running migrations for environment:%{reset} #{args.environment}"

      migrations = require "lapis.db.migrations"
      migrations.run_migrations require(args.migrations_module), nil, {
        transaction: args.transaction
        dry_run: args.dry_run
      }

      env.pop!
  }

  {
    name: "generate"
    help: "Generates a new file in the current directory from template"

    argparse: (command) ->
      with command
        \handle_options false
        \argument("template_name", "Which template to load (eg. model, flow, spec)")
        \argument("template_args", "Template arguments")\argname("<args>")\args("*")

        -- Example to add language picking to a generators argparser function
        -- \mutex(
        --   \flag "--moonscript --moon", "Prefer to generate MoonScript file when appropriate"
        --   \flag "--lua", "Prefer to generate Lua file when appropriate"
        -- )

    (args) =>
      {:template_name } = args

      local tpl, module_name

      if template_name == "--help" or template_name == "-h"
        return @execute {"help", "generate"}

      -- Try to load the template from the local generators directory
      pcall ->
        module_name = "generators.#{template_name}"
        tpl = require module_name

      unless tpl
        tpl = require "lapis.cmd.templates.#{template_name}"

      unless type(tpl) == "table"
        error "invalid generator `#{module_name or template_name}`: module must be table"

      unless type(tpl.write) == "function"
        error "invalid generator `#{module_name or template_name}`: is missing write function"

      writer = @make_template_writer!

      template_args = if tpl.argparser
        parse_args = tpl.argparser!
        -- we wrap it in a table to be unpacked when calling write
        { parse_args\parse args.template_args }
      elseif tpl.check_args
        -- NOTE: check_args is deprecated and is only for backwards compatibility with old generators
        tpl.check_args unpack args.template_args
        args.template_args

      tpl.write writer, unpack template_args
  }

  {
    name: "simulate"
    help: "Execute a mock HTTP request to your application code without any server involved"

    argparse: (command) ->
      with command
        \argument "path", "Path to request, may include query parameters (eg. /)"
        \option("--app-class", "Override default app class module name")
        \option("--helper", "Module name to require before loading app")

        \group("Request control"
          \option("--method", "HTTP method")\choices({"GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"})\default "GET"
          \option("--body", "Body of request, - for stdin")
          \option("--form -F", "Set method to POST if unset, content type to application/x-www-form-urlencoded, and body to value of this option")\count "*"
          \option("--header -H", "Append an input header, can be used multiple times (can overwrite set headers from other options")\count "*"
          \option("--host", "Set the host header of request")
          \option("--scheme", "Override default scheme (eg. https, http)")
          \flag("--json", "Set accept header to application/json")
          \flag("--csrf", "Set generated CSRF header and parameter for form requests")
        )

        \group("Display options"
          \flag "--print-headers", "Print only the headers as JSON"
          \flag "--print-json", "Print the entire response as JSON"
        )

    (args) =>
      import set_default_environment from require "lapis.environment"
      set_default_environment args.environment

      if args.helper
        require args.helper

      config = require("lapis.config").get!
      app_module = args.app_class or config.app_class or "app"
      app_cls = require app_module or config.app_class

      import mock_request from require "lapis.spec.request"

      local input_headers, input_cookies

      if args.json
        input_headers or= {}
        input_headers["Accept"] = "application/json"

      if args.body == "-"
        args.body = io.stdin\read "*a"

      if args.csrf
        import generate_token from require "lapis.csrf"
        args.form or= {}
        input_cookies or= {}
        import encode_query_string from require "lapis.util"
        table.insert args.form, encode_query_string {
          csrf_token:  generate_token { cookies: input_cookies }
        }

      if args.form and next args.form
        input_headers or= {}
        input_headers["Content-Type"] = "application/x-www-form-urlencoded"
        args.method = "POST" if args.method == "GET"
        args.body = table.concat args.form, "&"

      if args.header and next args.header
        for row in *args.header
          name, value = row\match "([^:]+):%s*(.+)"
          continue unless name
          input_headers or= {}
          input_headers[name] = value

      request_options = {
        method: args.method
        host: args.host
        body: args.body
        headers: input_headers
        cookies: input_cookies
        scheme: args.scheme
      }

      status, response, headers = assert mock_request app_cls, args.path, request_options

      if args.print_json
        import to_json from require "lapis.util"

        -- look for a session set in the cookies to decode
        import extract_cookies from require "lapis.spec.request"
        session = if response_cookies = extract_cookies headers
          import get_session from require "lapis.session"
          get_session {
            cookies: response_cookies
          }

        print to_json {
          :status, :response, :headers, :session
        }
      elseif args.print_headers
        import to_json from require "lapis.util"
        print to_json headers
      else
        colors = require "ansicolors"
        io.stderr\write colors "%{green}Status%{reset}: #{status}\n"

        header_names = [k for k in pairs headers]
        table.sort header_names

        for h in *header_names
          h_value = headers[h]
          if type(h_value) != "table"
            h_value = { tostring h_value }

          for v in *h_value
            io.stderr\write colors "%{yellow}#{h}%{reset}: #{v}\n"

        print response
  }

  {
    name: "_"
    hidden: true
    help: "Excute third-party command from module lapis.cmd.actions._"

    argparse: (command) ->
      with command
        \handle_options false
        \argument("sub_command", "Which command module to load")\argname("<command>")
        \argument("sub_command_args", "Arguments to command")\argname("<args>")\args("*")

    (args) =>
      switch args.sub_command
        when "--help", "-h"
          return @execute {"help", "_"}

      action = require "lapis.cmd.actions.#{args.sub_command}"

      command_args = if action.argparser
        parse_args = action.argparser!
        -- pass two args objects, firt the sub command args, then the lapis
        -- command's parsed arguments (for getting global flags like
        -- --environment)
        { parse_args\parse(args.sub_command_args), args }
      else
        -- this runs commands legacy style, from before argparse support was added
        import parse_flags from require "lapis.cmd.util"
        flags, rest = parse_flags args.sub_command_args
        flags.environment or= args.environment
        { flags, unpack rest}

      action[1] @, unpack command_args
  }

  custom_action {
    name: "systemd"
    help: "Generate systemd service file"
  }

  custom_action {
    name: "annotate"
    help: "Annotate model files with schema information"
  }

  custom_action {
    name: "eswidget"
    help: "Widget asset compilation and build generation"
  }

  {
    name: "debug"
    hidden: true
    help: "Debug information for test sutie"
    test_available: ->
      import running_in_test from require "lapis.spec"
      running_in_test!

    argparse: (command) ->
      add_environment_argument command

    (args) => args
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

    de = default_environment!

    parser = argparse "lapis",
      table.concat {
        "Control & create web applications written with Lapis"
        colors "Lapis: %{bright}#{require "lapis.version"}"
        if de == "development"
          colors "Default environment: %{yellow}#{de}"
        else
          colors "Default environment: %{bright green}#{de}"

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

    parser\option("--environment", "Override the environment name")\argname("<name>")
    parser\option("--config-module", "Override module name to require configuration from (default: config)")\argname("<name>")
    parser\flag "--trace", "Show full error trace if lapis command fails"

    for command_spec in *COMMANDS
      if command_spec.test_available
        continue unless command_spec.test_available!

      name = command_spec.name
      if command_spec.aliases
        name = "#{name} #{table.concat command_spec.aliases, " "}"

      help_string = command_spec.help

      if command_spec.context
        help_string = "#{help_string} (server: #{table.concat command_spec.context, ", "})"

      command = parser\command name, help_string

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

  -- self object used for generator templates
  make_template_writer: =>
    {
      command_runner: @
      write: (_, ...) ->
        success, err = @write_file_safe ...
        unless success
          @fail_with_message err

      mod_to_path: (mod, lang) =>
        p = mod\gsub "%.", "/"

        switch lang
          when "lua"
            "#{p}.lua"
          when "moonscript"
            "#{p}.moon"
          when nil
            p
          else
            error "Got unknown language for mod_to_path: #{lang}"


      default_language: default_language!
    }

  write_file_safe: (file, content) =>
    return nil, "file already exists: #{file}" if @path.exists file
    assert type(content) == "string", "write_file_safe: content must be a string, got #{type content}"

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

    assert action, "Failed to find command: #{args.command}"

    -- override the default config module if specified
    if args.config_module
      package.loaded["lapis.config_module_name"] = args.config_module

    -- verify if command works with active config
    if action.context
      assert @check_context args.environment, action.context

    unless args.environment
      import default_environment from require "lapis.environment"
      args.environment = default_environment!

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


  get_config: (environment) =>
    require("lapis.config").get environment

  get_server_type: (environment) =>
    (assert @get_config(environment).server, "Failed to get server type from config (did you set `server`?)")

  get_server_module: (environment) =>
    require "lapis.cmd.#{@get_server_type environment}"

  get_server_actions: (environment) =>
    require "lapis.cmd.#{@get_server_type environment}.actions"

  check_context: (environment, contexts) =>
    s = @get_server_module environment

    for c in *contexts
      return true if c == s.type

    nil, "Command not available for selected server (using #{s.type}, needs #{table.concat contexts, ", "})"

  get_command: (name) =>
    for k,v in ipairs COMMANDS
      return v if v.name == name

command_runner = CommandRunner!

{
  :command_runner

  get_command: command_runner\get_command
  execute: command_runner\execute_safe
}

