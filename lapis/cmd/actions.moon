
import columnize from require "lapis.cmd.util"
import find_nginx from require "lapis.cmd.nginx"
path = require "lapis.cmd.path"

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
  mkdir: "made directory"
  write_file: "wrote"
}

local tasks
tasks = {
  default: "help"

  {
    name: "new"
    help: "create a new lapis project in the current directory"
    ->
      if path.exists "nginx.conf"
        print "Aborting, nginx.conf already exists"
        return

      path.mkdir "logs"
      path.mkdir "conf"
      path.write_file "nginx.conf", require "lapis.cmd.templates.config"
      path.write_file "mime.types", require "lapis.cmd.templates.mime_types"
  }

  {
    name: "server"
    help: "start the development server"
    ->
      -- compile config
      import compile_config from require "lapis.cmd.nginx"
      compiled = compile_config path.read_file"nginx.conf", {
        port: "8080"
        num_workers: "1"
      }
      path.write_file "nginx.conf.compiled", compiled
      os.execute find_nginx! .. ' -p "$(pwd)" -c "nginx.conf.compiled"'
  }

  {
    name: "help"
    help: "show this text"

    ->
      print "Lapis #{require "lapis.version"}"
      print "usage: lapis <action> [arguments]"
      print "using nginx: #{find_nginx!}"
      print!
      print "Available actions:"
      print!
      print columnize [ { t.name, t.help } for t in *tasks ]
      print!
  }
}

get_task = (name) ->
  for k,v in ipairs tasks
    return v if v.name == name

execute = (args) ->
  task_name = args[1] or tasks.default
  if task = get_task(task_name)
    assert(task[1], "action `#{task_name}' not implemented") args
  else
    print "Error: unknown command `#{task_name}'"
    get_task("help")[1] args

{ :tasks, :execute }

