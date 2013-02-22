
local *

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
  with io.open path, "w"
    \write content
    \close!

mkdir = (path) ->
  os.execute "mkdir -p #{path}"

copy = (src, dest) ->
  os.execute "cp #{src} #{dest}"

join = (a, b) ->
  a = a\match"^(.*)/$" or a if a != "/"
  b = b\match"^/(.*)$" or b
  return b if a == ""
  return a if b == ""
  a .. "/" .. b


{ :up, :exists, :normalize, :basepath, :filename, :write_file, :mkdir, :copy,
  :join }
