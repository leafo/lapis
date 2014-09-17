local io = io
local up, exists, normalize, basepath, filename, write_file, read_file, mkdir, copy, join
up = function(path)
  path = path:gsub("/$", "")
  path = path:gsub("[^/]*$", "")
  if path ~= "" then
    return path
  end
end
exists = function(path)
  local file = io.open(path)
  if file then
    return file:close() and true
  end
end
normalize = function(path)
  return (path:gsub("^%./", ""))
end
basepath = function(path)
  return (path:match("^(.*)/[^/]*$") or ".")
end
filename = function(path)
  return (path:match("([^/]*)$"))
end
write_file = function(path, content)
  assert(content, "trying to write file with no content")
  do
    local _with_0 = io.open(path, "w")
    _with_0:write(content)
    _with_0:close()
    return _with_0
  end
end
read_file = function(path)
  local file = io.open(path)
  if not (file) then
    error("file doesn't exist `" .. tostring(path) .. "'")
  end
  do
    local _with_0 = file:read("*a")
    file:close()
    return _with_0
  end
end
mkdir = function(path)
  return os.execute("mkdir -p " .. tostring(path))
end
copy = function(src, dest)
  return os.execute("cp " .. tostring(src) .. " " .. tostring(dest))
end
join = function(a, b)
  if a ~= "/" then
    a = a:match("^(.*)/$") or a
  end
  b = b:match("^/(.*)$") or b
  if a == "" then
    return b
  end
  if b == "" then
    return a
  end
  return a .. "/" .. b
end
return {
  up = up,
  exists = exists,
  normalize = normalize,
  basepath = basepath,
  filename = filename,
  write_file = write_file,
  mkdir = mkdir,
  copy = copy,
  join = join,
  read_file = read_file
}
