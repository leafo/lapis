argparser = ->
  with require("argparse") "lapis generate rockspec", "Generate a LuaRocks rockspec file for managing dependencies"
    \option("--app-name", "The name of the app to use for the rockspec. Defaults to name of current directory")
    \option("--version-name", "Version of rockspec file to generate")\default "dev-1"

    \group("Dependencies"
      \flag "--cqueues", "Include dependencies for cqueues server support"
      \flag "--moonscript --moon", "Include MoonScript as dependency"
      \flag "--sqlite", "Include SQLite dependencies"
      \flag "--postgresql --postgres", "Include PostgreSQL dependencies"
      \flag "--mysql", "Include MySQL dependency"
    )

rockspec_template = [[
package = %q
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

detect_app_name = ->
  import trim, slugify from require "lapis.util"
  local dir_name

  pcall ->
    handle = io.popen "basename $(pwd)"
    out = handle\read!
    dir_name = slugify trim out
    handle\close!

  dir_name

detect_repository_url = ->
  local url
  import trim from require "lapis.util"

  pcall ->
    if 0 == os.execute "git remote &> /dev/null"
      handle = io.popen "git remote get-url origin"
      url = handle\read!
      handle\close!

  url

write = (args) =>
  app_name = args.app_name or detect_app_name! or "lapis-app"
  source_url = detect_repository_url!

  out_file = "#{app_name}-#{args.version_name}.rockspec"

  dependencies = {
    "lua ~> 5.1",
    "lapis == #{require("lapis.version")}"
  }

  if args.cqueues
    table.insert dependencies, "cqueues"
    table.insert dependencies, "http"

  if args.moonscript
    table.insert dependencies, "moonscript"

  if args.postgresql
    table.insert dependencies, "pgmoon"

  if args.sqlite
    table.insert dependencies, "lsqlite3"

  if args.mysql
    table.insert dependencies, "luasql-mysql"

  formatted_deps = for d in *dependencies
    [[  %q]]\format d

  @write out_file, rockspec_template\format(
    app_name,
    args.version_name,
    source_url or "",
    table.concat formatted_deps, ",\n"
  )

{:argparser, :write}
