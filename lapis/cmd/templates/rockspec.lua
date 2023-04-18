local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate rockspec", "Generate a LuaRocks rockspec file for managing dependencies")
    _with_0:option("--app-name", "The name of the app to use for the rockspec. Defaults to name of current directory")
    _with_0:option("--version-name", "Version of rockspec file to generate"):default("dev-1")
    _with_0:group("Dependencies", _with_0:flag("--cqueues", "Include dependencies for cqueues server support"), _with_0:flag("--moonscript --moon", "Include MoonScript as dependency"), _with_0:flag("--sqlite", "Include SQLite dependencies"), _with_0:flag("--postgresql --postgres", "Include PostgreSQL dependencies"), _with_0:flag("--mysql", "Include MySQL dependency"))
    return _with_0
  end
end
local rockspec_template = [[package = %q
version = %q

source = {
  url = %q
}

description = {
  summary = "Lapis Application",
  homepage = "",
  license = ""
}

dependencies = {
%s
}

build = {
  type = "none"
}
]]
local detect_app_name
detect_app_name = function()
  local trim, slugify
  do
    local _obj_0 = require("lapis.util")
    trim, slugify = _obj_0.trim, _obj_0.slugify
  end
  local dir_name
  pcall(function()
    local handle = io.popen("basename $(pwd)")
    local out = handle:read()
    dir_name = slugify(trim(out))
    return handle:close()
  end)
  return dir_name
end
local detect_repository_url
detect_repository_url = function()
  local url
  local trim
  trim = require("lapis.util").trim
  pcall(function()
    if 0 == os.execute("git remote &> /dev/null") then
      local handle = io.popen("git remote get-url origin")
      url = handle:read()
      return handle:close()
    end
  end)
  return url
end
local write
write = function(self, args)
  local app_name = args.app_name or detect_app_name() or "lapis-app"
  local source_url = detect_repository_url()
  local out_file = tostring(app_name) .. "-" .. tostring(args.version_name) .. ".rockspec"
  local dependencies = {
    "lua ~> 5.1",
    "lapis == " .. tostring(require("lapis.version"))
  }
  if args.cqueues then
    table.insert(dependencies, "cqueues")
    table.insert(dependencies, "http")
  end
  if args.moonscript then
    table.insert(dependencies, "moonscript")
  end
  if args.postgresql then
    table.insert(dependencies, "pgmoon")
  end
  if args.sqlite then
    table.insert(dependencies, "lsqlite3")
  end
  if args.mysql then
    table.insert(dependencies, "luasql-mysql")
  end
  local formatted_deps
  do
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #dependencies do
      local d = dependencies[_index_0]
      _accum_0[_len_0] = ([[  %q]]):format(d)
      _len_0 = _len_0 + 1
    end
    formatted_deps = _accum_0
  end
  return self:write(out_file, rockspec_template:format(app_name, args.version_name, source_url or "", table.concat(formatted_deps, ",\n")))
end
return {
  argparser = argparser,
  write = write
}
