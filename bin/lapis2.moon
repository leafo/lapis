
-- This is work in progress migrations of the lapis command to use argparse

import default_environment from require "lapis.environment"
import find_nginx from require "lapis.cmd.nginx"

colors = require "ansicolors"
argparse = require "argparse"


lua_http_status_string = ->
  local str
  pcall ->
    str = colors "cqueues: %{bright}#{require("cqueues").VERSION}%{reset} lua-http: %{bright}#{require("http.version").version}%{reset}"

  str


parser = argparse "lapis",
  table.concat {
    "Control & create web applications written with Lapis"
    colors "Lapis: %{bright}#{require "lapis.version"}"
    colors "Default environment: %{yellow}#{default_environment!}"
    if nginx = find_nginx!
      colors "OpenResty: %{bright}#{nginx}"
    else
      "No OpenResty installation found"

    if status = lua_http_status_string!
      status
    else
      "cqueues lua-http: not available"
  }, "\n"

parser\command_target "action"
parser\add_help_command!

parser\option "--environment", "Override the default environment"

with parser\command "new", "Create a new Lapis project in the current directory"
  \mutex(
    \flag "--cqueues", "Generate config for cqueues server"
    \flag "--nginx", "Generate config for nginx server"
  )
  \mutex(
    \flag "--lua", "Generate app template file in Lua"
    \flag "--moonscript --moon", "Generate app template file in MoonScript"
  )
  \flag "--etlua-config", "Use etlua for templmated configuration files (eg. nginx.conf)"
  \flag "--git", "Generate default .gitignore file"
  \flag "--tup", "Generate default Tupfile"

with parser\command "server serve", "Start the server from the current directory"
  \argument("environment")\args "?"

with parser\command "build", "Rebuild configuration and send a reload signal to running server"
  \argument("environment")\args "?"

parser\command "term", "Sends TERM signal to shut down a running server"

with parser\command "exec execute", "Execute Lua on the server"
  \argument "code", "String code to execute. Set - to read code from stdin"
  \mutex(
    \flag "--moonscript --moon", "Execute code as MoonScript"
    \flag "--lua", "Execute code as Lua"
  )

with parser\command "migrate", "Run any outstanding migrations"
  \argument("environment")\args "?"
  \option("--transaction")\args("?")\choices({"global", "individual"})\action (args, name, val) ->
    -- flatten the table that's created from args("?")
    args[name] = val[next(val)] or true
    print args, name, val


with parser\command "generate", "Generates a new file in the current directory from template"
  \argument("template", "Which template to load (eg. model, flow)")
  \argument("args", "Template arguments")\args("*")
  \mutex(
    \flag "--moonscript --moon", "Prefer to generate MoonScript file when appropriate"
    \flag "--lua", "Prefer to generate Lua file when appropriate"
  )

with parser\command "_", "Excute third-party command from module lapis.cmd.actions._"
  \handle_options false
  \argument("subcommand", "Which command module to load")
  \argument("args", "Arguments to command")\args("*")

-- try to load secondary commands
pcall ->
  systemd = require("lapis.cmd.actions.systemd")
  with parser\command "systemd", "Generate systemd service file"
    \argument("sub_command")\choices {"service"}
    \argument("environment")\args "?"
    \flag("--install", "Installs the service file to the system, requires sudo permission")


pcall ->
  systemd = require("lapis.cmd.actions.annotate")
  with parser\command "annotate", "Annotate model files with schema information"
    \argument("files", "Paths to model classes to annotate (eg. models/first.moon models/second.moon ...)")\args "+"


args = parser\parse [v for _, v in ipairs _G.arg]

require("moon").p args
