
import columnize from require "lapis.cmd.util"
path = require "lapis.cmd.path"

log = (...) ->
  print "->", ...

find_nginx = do
  nginx_bin = "nginx"
  nginx_search_paths = {
    "/usr/local/openresty/nginx/sbin/"
    "/usr/sbin/"
    ""
  }

  local nginx_path
  ->
    return nginx_path if nginx_path
    for prefix in *nginx_search_paths
      cmd = "#{prefix}#{nginx_bin} -v 2>&1"
      handle = io.popen cmd
      out = handle\read!
      handle\close!

      if out\match "^nginx version: ngx_openresty/1.2.6.6"
        nginx_path = "#{prefix}#{nginx_bin}"
        return nginx_path


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
      path.mkdir "logs"
      path.mkdir "conf"
      path.write_file "nginx.conf", require "lapis.cmd.templates.config"
      path.write_file "mime.types", require "lapis.cmd.templates.mime_types"
  }

  {
    name: "server"
    help: "start the development server"
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
  get_task(task_name)[1] args

{ :tasks, :execute }

