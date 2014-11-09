
import default_environment, columnize from require "lapis.cmd.util"
import find_nginx, start_nginx, write_config_for, get_pid from require "lapis.cmd.nginx"
import find_leda, start_leda from require "lapis.cmd.leda"

path = require "lapis.cmd.path"
config = require "lapis.config"

colors = require "ansicolors"

log = print
annotate = (obj, verbs) ->
  setmetatable {}, {
    __newindex: (name, value) =>
      obj[name] = value
    __index: (name) =>
      fn =  obj[name]
      return fn if not type(fn) == "function"
      if verbs[name]
        (...) ->
          fn ...
          first = ...
          log verbs[name], first
      else
        fn
  }

path = annotate path, {
  mkdir: colors "%{bright}%{magenta}made directory%{reset}"
  write_file: colors "%{bright}%{yellow}wrote%{reset}"
}

write_file_safe = (file, content) ->
  return if path.exists file
  path.write_file file, content

fail_with_message = (msg) ->
  print colors "%{bright}%{red}Aborting:%{reset} " .. msg
  os.exit 1

parse_flags = (...) ->
  input = {...}
  flags = {}

  filtered = for arg in *input
    if flag = arg\match "^%-%-?(.+)$"
      k,v = flag\match "(.-)=(.*)"
      if k
        flags[k] = v
      else
        flags[flag] = true
      continue
    arg

  flags, unpack filtered

local tasks

get_task = (name) ->
  for k,v in ipairs tasks
    return v if v.name == name

tasks = {
  default: "help"

  {
    name: "new"
    help: "create a new lapis project in the current directory"

    (...) ->
      import CONFIG_PATH, CONFIG_PATH_ETLUA from require "lapis.cmd.nginx"
      flags = parse_flags ...

      if path.exists(CONFIG_PATH) or path.exists(CONFIG_PATH_ETLUA)
        fail_with_message "nginx.conf already exists"

      if flags["etlua-config"]
        write_file_safe CONFIG_PATH_ETLUA, require "lapis.cmd.templates.config_etlua"
      else
        write_file_safe CONFIG_PATH, require "lapis.cmd.templates.config"

      write_file_safe "mime.types", require "lapis.cmd.templates.mime_types"

      if flags.lua
        write_file_safe "app.lua", require "lapis.cmd.templates.app_lua"
      else
        write_file_safe "app.moon", require "lapis.cmd.templates.app"

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

    (environment=default_environment!) ->
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

    (environment=default_environment!) ->
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

    (signal) ->
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

    (code, environment=default_environment!) ->
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

    (environment=default_environment!) ->
      import attach_server from require "lapis.cmd.nginx"

      unless get_pid!
        print colors "%{green}Using temporary server..."


      server = attach_server environment
      print server\exec [[
        local migrations = require("lapis.db.migrations")
        migrations.create_migrations_table()
        migrations.run_migrations(require("migrations"))
      ]]
      server\detach!
  }

  {
    name: "generate"
    usage: "generate template [args...]"
    help: "generates a new file from template"

    (template_name, ...) ->
      tpl = require "lapis.cmd.templates.#{template_name}"
      unless type(tpl) == "table"
        error "invalid template: #{template_name}"

      out = tpl.content ...
      fname = tpl.filename ...
      write_file_safe fname, out
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
      print columnize [ { t.usage or t.name, t.help } for t in *tasks when not t.hidden ]
      print!
  }
}

format_error = (msg) ->
  colors "%{bright red}Error:%{reset} #{msg}"

execute = (args) ->
  task_name = args[1] or tasks.default
  task_args = [a for i, a in ipairs args when i > 1]

  task = get_task(task_name)

  unless task
    print format_error "unknown command `#{task_name}'"
    get_task("help")[1] unpack task_args
    return

  fn = assert(task[1], "action `#{task_name}' not implemented")
  xpcall (-> fn unpack task_args), (err) ->
    flags = parse_flags unpack task_args
    err = err\match("^.-:.-:.(.*)$") or err unless flags.trace
    msg = colors "%{bright red}Error:%{reset} #{err}"
    if flags.trace
      print debug.traceback msg, 2
    else
      print msg
      print " * Run with --trace to see traceback"
      print " * Report issues to https://github.com/leafo/lapis/issues"

    os.exit 1

{ :tasks, :execute }

