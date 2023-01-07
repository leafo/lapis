
io = io

shell_escape = (str) ->
  str\gsub "'", "'\\''"

local *

-- Setting this environment variable will prevent altering the file system and
-- just print written files to stdout
LAPIS_GENERATE_STDOUT = os.getenv "LAPIS_GENERATE_STDOUT"

-- move up a directory
-- /hello/world -> /hello
up = (path) ->
  path = path\gsub "/$", ""
  path = path\gsub "[^/]*$", ""
  path if path != ""

exists = (path) ->
  file = io.open path
  file\close! and true if file

normalize = (path) ->
  (path\gsub "^%./", "")

basepath = (path) ->
  (path\match"^(.*)/[^/]*$" or ".")

filename = (path) ->
  (path\match"([^/]*)$")

write_file = (path, content) ->
  assert content, "trying to write file with no content"

  if LAPIS_GENERATE_STDOUT
    print content
  else
    with assert io.open path, "w"
      \write content
      \close!

read_file = (path) ->
  file = io.open path
  error "file doesn't exist `#{path}'" unless file
  with file\read "*a"
    file\close!

mkdir = (path) ->
  if LAPIS_GENERATE_STDOUT
    return -- do nothing
  os.execute "mkdir -p '#{shell_escape path}'"

join = (a, b) ->
  a = a\match"^(.*)/$" or a if a != "/"
  b = b\match"^/(.*)$" or b
  return b if a == ""
  return a if b == ""
  a .. "/" .. b

exec = (cmd, ...) ->
  args = [shell_escape x for x in *{...}]
  args = table.concat args, " "

  full_cmd = "#{cmd} #{args}"
  os.execute full_cmd

mod = {
  :up, :exists, :normalize, :basepath, :filename, :write_file, :mkdir
  :join, :read_file, :shell_escape, :exec
}

mod.annotate = do
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
            log verbs[name], (...)
            fn ...
        else
          fn
    }

  ->
    colors = require "ansicolors"
    annotate mod, {
      mkdir: colors "%{bright}%{magenta}make directory%{reset}"
      write_file: colors "%{bright}%{yellow}write%{reset}"
      exec: colors "%{bright}%{red}exec%{reset}"
    }

mod
