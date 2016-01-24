
import default_environment, columnize, parse_flags from require "lapis.cmd.util"
import find_nginx, start_nginx, write_config_for, get_pid from require "lapis.cmd.nginx"
import find_leda, start_leda from require "lapis.cmd.leda"

path = require "lapis.cmd.path"
colors = require "ansicolors"

path = path\annotate!
set_path = (p) -> path = p

write_file_safe = (file, content) ->
  return nil, "file already exists: #{file}" if path.exists file

  if prefix = file\match "^(.+)/[^/]+$"
    path.mkdir prefix unless path.exists prefix

  path.write_file file, content
  true

fail_with_message = (msg) ->
  print colors "%{bright}%{red}Aborting:%{reset} " .. msg
  os.exit 1

local actions

get_action = (name) ->
  for k,v in ipairs actions
    return v if v.name == name

  -- no match, try package
  local action
  pcall ->
    action = require "lapis.cmd.actions.#{name}"

  action

actions = {
  default: "help"

  {
    name: "new"
    help: "create a new lapis project in the current directory"

    (flags) ->
      import config_path, config_path_etlua from require("lapis.cmd.nginx").nginx_runner

      if path.exists(config_path) or path.exists(config_path_etlua)
        fail_with_message "nginx.conf already exists"

      if flags["etlua-config"]
        write_file_safe config_path_etlua, require "lapis.cmd.templates.config_etlua"
      else
        write_file_safe config_path, require "lapis.cmd.templates.config"

      write_file_safe "mime.types", require "lapis.cmd.templates.mime_types"

      if flags.lua
        write_file_safe "app.lua", require "lapis.cmd.templates.app_lua"
        write_file_safe "models.lua", require "lapis.cmd.templates.models_lua"
      else
        write_file_safe "app.moon", require "lapis.cmd.templates.app"
        write_file_safe "models.moon", require "lapis.cmd.templates.models"

      if flags.git
        write_file_safe ".gitignore", require("lapis.cmd.templates.gitignore") flags

      if flags.tup
        tup_files = require "lapis.cmd.templates.tup"
        for fname, content in pairs tup_files
          write_file_safe fname, content
  }

  {
    name: "server"
    usage: "server [environment]"
    help: "build config and start server"

    (flags, environment=default_environment!) ->
      nginx = find_nginx!
      leda = find_leda!

      unless nginx or leda
        fail_with_message "can not find suitable server installation"

      if nginx
        write_config_for environment
        start_nginx!
      else
        start_leda environment

  }

  {
    name: "build"
    usage: "build [environment]"
    help: "build config, send HUP if server running"

    (flags, environment=default_environment!) ->
      write_config_for environment

      import send_hup from require "lapis.cmd.nginx"
      pid = send_hup!
      print colors "%{green}HUP #{pid}" if pid
  }

  {
    name: "hup"
    hidden: true
    help: "send HUP signal to running server"

    ->
      import send_hup from require "lapis.cmd.nginx"
      pid = send_hup!
      if pid
        print colors "%{green}HUP #{pid}"
      else
        fail_with_message "failed to find nginx process"
  }

  {
    name: "term"
    help: "sends TERM signal to shut down a running server"

    ->
      import send_term from require "lapis.cmd.nginx"
      pid = send_term!
      if pid
        print colors "%{green}TERM #{pid}"
      else
        fail_with_message "failed to find nginx process"

  }

  {
    name: "signal"
    hidden: true
    help: "send arbitrary signal to running server"

    (flags, signal) ->
      assert signal, "Missing signal"
      import send_signal from require "lapis.cmd.nginx"

      pid = send_signal signal
      if pid
        print colors "%{green}Sent #{signal} to #{pid}"
      else
        fail_with_message "failed to find nginx process"
  }

  {
    name: "exec"
    usage: "exec <lua-string>"
    help: "execute Lua on the server"

    (flags, code, environment=default_environment!) ->
      fail_with_message("missing lua-string: exec <lua-string>") unless code
      import attach_server from require "lapis.cmd.nginx"

      unless get_pid!
        print colors "%{green}Using temporary server..."

      server = attach_server environment
      print server\exec code
      server\detach!
  }

  {
    name: "migrate"
    usage: "migrate [environment]"
    help: "run migrations"

    (flags, environment=default_environment!) ->
      env = require "lapis.environment"
      env.push environment, show_queries: true

      migrations = require "lapis.db.migrations"
      migrations.run_migrations require "migrations"

      env.pop!
  }

  {
    name: "generate"
    usage: "generate <template> [args...]"
    help: "generates a new file from template"

    (flags, template_name, ...) ->
      local tpl, module_name

      pcall ->
        module_name = "generators.#{template_name}"
        tpl = require module_name

      unless tpl
        tpl = require "lapis.cmd.templates.#{template_name}"

      unless type(tpl) == "table"
        error "invalid generator `#{module_name or template_name}`, module must be table"

      writer = {
        write: (...) => assert write_file_safe ...
        mod_to_path: (mod) =>
          mod\gsub "%.", "/"

      }

      if tpl.check_args
        tpl.check_args ...

      unless type(tpl.write) == "function"
        error "generator `#{module_name or template_name}` is missing write function"

      tpl.write writer, ...
  }

  {
    name: "help"
    help: "show this text"

    ->
      print colors "Lapis #{require "lapis.version"}"
      print "usage: lapis <action> [arguments]"

      nginx = find_nginx!
      leda = find_leda!
      if nginx
        print "using nginx: #{nginx}"
      elseif leda
        print "using leda: #{leda}"
      else
        print "can not find suitable server installation"

      print "default environment: #{default_environment!}"
      print!
      print "Available actions:"
      print!
      print columnize [ { t.usage or t.name, t.help } for t in *actions when not t.hidden ]
      print!
  }
}

format_error = (msg) ->
  colors "%{bright red}Error:%{reset} #{msg}"

execute = (args) ->
  args = {i, a for i, a in pairs(args) when type(i) == "number" and i > 0}
  flags, plain_args = parse_flags args

  action_name = plain_args[1] or actions.default
  action = get_action action_name

  rest = [arg for arg in *plain_args[2,]]

  unless action
    print format_error "unknown command `#{action_name}'"
    get_action("help")[1] unpack rest
    return

  fn = assert(action[1], "action `#{action_name}' not implemented")
  xpcall (-> fn flags, unpack rest), (err) ->
    err = err\match("^.-:.-:.(.*)$") or err unless flags.trace
    msg = colors "%{bright red}Error:%{reset} #{err}"
    if flags.trace
      print debug.traceback msg, 2
    else
      print msg
      print " * Run with --trace to see traceback"
      print " * Report issues to https://github.com/leafo/lapis/issues"

    os.exit 1

{ :actions, :execute, :get_action, :parse_flags, :set_path }

