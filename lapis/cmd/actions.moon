
import columnize from require "lapis.cmd.util"
import find_nginx from require "lapis.cmd.nginx"
path = require "lapis.cmd.path"
config = require "lapis.config"

colors = require "ansicolors"

log = (...) ->
  print "->", ...

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
tasks = {
  default: "help"

  {
    name: "new"
    help: "create a new lapis project in the current directory"

    (...) ->
      flags = parse_flags ...

      if path.exists "nginx.conf"
        print colors "%{bright}%{red}Aborting:%{reset} nginx.conf already exists"
        return

      write_file_safe "nginx.conf", require "lapis.cmd.templates.config"
      write_file_safe "mime.types", require "lapis.cmd.templates.mime_types"
      write_file_safe "web.moon", require "lapis.cmd.templates.web"

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
    help: "start the server"

    (environment="development") ->
      nginx = find_nginx!
      unless nginx
        print "Aborting, can not find an installation of OpenResty"
        return

      -- load app config
      vars = config.get environment

      -- compile config
      import compile_config from require "lapis.cmd.nginx"
      compiled = compile_config path.read_file"nginx.conf", vars

      path.write_file "nginx.conf.compiled", compiled

      path.mkdir "logs"

      os.execute "touch logs/error.log"
      os.execute "touch logs/access.log"
      os.execute "LAPIS_ENVIRONMENT='#{environment}' " .. nginx .. ' -p "$(pwd)" -c "nginx.conf.compiled"'
  }

  {
    name: "help"
    help: "show this text"

    ->
      print "Lapis #{require "lapis.version"}"
      print "usage: lapis <action> [arguments]"
      if nginx = find_nginx!
        print "using nginx: #{nginx}"
      else
        print "can not find installation of OpenResty"

      print!
      print "Available actions:"
      print!
      print columnize [ { t.usage or t.name, t.help } for t in *tasks ]
      print!
  }
}

get_task = (name) ->
  for k,v in ipairs tasks
    return v if v.name == name

execute = (args) ->
  task_name = args[1] or tasks.default
  task_args = [a for i, a in ipairs args when i > 1]

  if task = get_task(task_name)
    assert(task[1], "action `#{task_name}' not implemented") unpack task_args
  else
    print "Error: unknown command `#{task_name}'"
    get_task("help")[1] unpack task_args

{ :tasks, :execute }

