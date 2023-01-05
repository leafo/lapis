local default_environment
default_environment = require("lapis.environment").default_environment
local find_nginx
find_nginx = require("lapis.cmd.nginx").find_nginx
local colors = require("ansicolors")
local argparse = require("argparse")
local lua_http_status_string
lua_http_status_string = function()
  local str
  pcall(function()
    str = colors("cqueues: %{bright}" .. tostring(require("cqueues").VERSION) .. "%{reset} lua-http: %{bright}" .. tostring(require("http.version").version) .. "%{reset}")
  end)
  return str
end
local parser = argparse("lapis", table.concat({
  "Control & create web applications written with Lapis",
  colors("Lapis: %{bright}" .. tostring(require("lapis.version"))),
  colors("Default environment: %{yellow}" .. tostring(default_environment())),
  (function()
    do
      local nginx = find_nginx()
      if nginx then
        return colors("OpenResty: %{bright}" .. tostring(nginx))
      else
        return "No OpenResty installation found"
      end
    end
  end)(),
  (function()
    do
      local status = lua_http_status_string()
      if status then
        return status
      else
        return "cqueues lua-http: not available"
      end
    end
  end)()
}, "\n"))
parser:command_target("command")
parser:add_help_command()
parser:option("--environment", "Override the default environment"):default(default_environment())
parser:flag("--trace", "Show full error trace if lapis command fails")
do
  local _with_0 = parser:command("new", "Create a new Lapis project in the current directory")
  _with_0:mutex(_with_0:flag("--cqueues", "Generate config for cqueues server"), _with_0:flag("--nginx", "Generate config for nginx server"))
  _with_0:mutex(_with_0:flag("--lua", "Generate app template file in Lua"), _with_0:flag("--moonscript --moon", "Generate app template file in MoonScript"))
  _with_0:flag("--etlua-config", "Use etlua for templmated configuration files (eg. nginx.conf)")
  _with_0:flag("--git", "Generate default .gitignore file")
  _with_0:flag("--tup", "Generate default Tupfile")
end
do
  local _with_0 = parser:command("server serve", "Start the server from the current directory")
  _with_0:argument("environment"):args("?")
end
do
  local _with_0 = parser:command("build", "Rebuild configuration and send a reload signal to running server")
  _with_0:argument("environment"):args("?")
end
parser:command("term", "Sends TERM signal to shut down a running server")
do
  local _with_0 = parser:command("exec execute", "Execute Lua on the server")
  _with_0:argument("code", "String code to execute. Set - to read code from stdin")
  _with_0:mutex(_with_0:flag("--moonscript --moon", "Execute code as MoonScript"), _with_0:flag("--lua", "Execute code as Lua"))
end
do
  local _with_0 = parser:command("migrate", "Run any outstanding migrations")
  _with_0:argument("environment"):args("?")
  _with_0:option("--transaction"):args("?"):choices({
    "global",
    "individual"
  }):action(function(args, name, val)
    args[name] = val[next(val)] or true
    return print(args, name, val)
  end)
end
do
  local _with_0 = parser:command("generate", "Generates a new file in the current directory from template")
  _with_0:argument("template_name", "Which template to load (eg. model, flow)")
  _with_0:argument("template_args", "Template arguments"):args("*")
  _with_0:mutex(_with_0:flag("--moonscript --moon", "Prefer to generate MoonScript file when appropriate"), _with_0:flag("--lua", "Prefer to generate Lua file when appropriate"))
end
do
  local _with_0 = parser:command("_", "Excute third-party command from module lapis.cmd.actions._")
  _with_0:handle_options(false)
  _with_0:argument("subcommand", "Which command module to load")
  _with_0:argument("args", "Arguments to command"):args("*")
end
pcall(function()
  local systemd = require("lapis.cmd.actions.systemd")
  do
    local _with_0 = parser:command("systemd", "Generate systemd service file")
    _with_0:argument("sub_command"):choices({
      "service"
    })
    _with_0:argument("environment"):args("?")
    _with_0:flag("--install", "Installs the service file to the system, requires sudo permission")
    return _with_0
  end
end)
pcall(function()
  local systemd = require("lapis.cmd.actions.annotate")
  do
    local _with_0 = parser:command("annotate", "Annotate model files with schema information")
    _with_0:argument("files", "Paths to model classes to annotate (eg. models/first.moon models/second.moon ...)"):args("+")
    return _with_0
  end
end)
return parser
