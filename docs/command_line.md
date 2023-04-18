{
  title: "Command Line Interface"
}
# Command Line Interface

A `lapis` command is installed into your system when Lapis is installed with
LuaRocks. Run `lapis` in your terminal to install without any arguments to get
a summary of what it can do, along with information about the installation, eg.

    Usage: lapis [-h] [--environment <name>] [--config-module <name>]
           [--trace] <command> ...

    Control & create web applications written with Lapis
    Lapis: 1.14.0
    Default environment: development
    OpenResty: /usr/local/openresty/nginx/sbin/nginx
    cqueues: 20200726 lua-http: 0.4

    Options:
       -h, --help            Show this help message and exit.
       --environment <name>  Override the environment name
       --config-module <name>
                             Override module name to require configuration from (default: config)
       --trace               Show full error trace if lapis command fails

    Commands:
       help                  Show help for commands.
       new                   Create a new Lapis project in the current directory
       server, serve         Start the server from the current directory
       build                 Rebuild configuration and send a reload signal to running server (server: nginx)
       term                  Sends TERM signal to shut down a running server (server: nginx)
       exec, execute         Execute Lua on the server (server: nginx)
       migrate               Run any outstanding migrations
       generate              Generates a new file in the current directory from template
       simulate              Execute a mock HTTP request to your application code without any server involved


Note that some commands are only available for certain server types, eg. `lapis
term` is only available for OpenResty/nginx.

To learn more about a command you can type `lapis help COMMAND`, eg. `lapis
help migrate`.

## Default Environment

Lapis will load your Applications's configuration by for an environment before
executing a command. The default environment name in command line `development`
unless otherwise overwritten.

You can confirm what the default environment is by running `lapis help`.

You are free to use any environment name you want. You can change the
environment in a few different ways:

* Using the `--environment` flag on the `lapis` command will set the environment for the duration of the command
* For convenience, some commands can also take the environment as an argument after the command name, eg `lapis server production` (This will have the same effect as using `--environment`
* Creating a `lapis_environment.lua` file in your working directory that returns a string will allow you to change the default environment to whatever is returned
* Setting the `LAPIS_ENVIRONMENT` environment variable will change the default environment

Learn more about environments on the [Configuration](configuration.html) guide.

## Command Reference

### `lapis new`

    Usage: lapis new ([--nginx] | [--cqueues]) ([--lua] | [--moonscript])
           [-h] [--etlua-config] [--git] [--tup] [--rockspec] [--force]

    Create a new Lapis project in the current directory

    Options:
       -h, --help            Show this help message and exit.
       --nginx               Generate config for nginx server (default)
       --cqueues             Generate config for cqueues server
       --lua                 Generate app template file in Lua (defaul)
       --moonscript, --moon  Generate app template file in MoonScript
       --etlua-config        Use etlua for templated configuration files (eg. nginx.conf)
       --git                 Generate default .gitignore file
       --tup                 Generate default Tupfile
       --rockspec            Generate a rockspec file for managing dependencies
       --force               Bypass errors when detecting functional server environment


The `new` command will create a blank Lapis project in the current directory by
writing some starter files. Note that it is not necessary to use `lapis new` to
create a new Lapis project, but it can help you get started more quickly.

By default it creates the following files for a OpenResty server:

* `nginx.conf`
* `mime.types`
* `app.lua`
* `config.lua`

> Use the `--moonscript` flag to generate a blank MoonScript based app

The generated files are only starting points, you are encouraged to read, and
customize them.

The `--rockspec` flag can be used to generated a blank rockspec for managing
your app's dependencies. If you need to configure the rockspec file then you
can instead use `lapis generate rockspec` after creating your app.

### `lapis server`

```bash
$ lapis server [environment]
```

This command start the configured webserver for your app under the specified
environment. This command will first read your configuration file to determine
the server type for the environment, then it will attempt to start your
application using the entry point for the app.

#### OpenResty Server

The default configuration utilizes OpenResty as the webserver. The `server`
command first builds the config, ensures logs exist, then starts the nginx
binary with the local `nginx.conf` file.

Lapis ensures that it runs a version of Nginx that is OpenResty. It will search
`$PATH` and any common OpenResty installation directories to find the correct
binary.

Lapis searches the following directories for an installation of OpenResty:

    "/usr/local/openresty/nginx/sbin/"
    "/usr/local/opt/openresty/bin/"
    "/usr/sbin/"
    ""

If you need to manually specify the location of the OpenResty binary you can do
so with the `LAPIS_OPENRESTY` environment variable:

    LAPIS_OPENRESTY=/home/leafo/bin/openresty lapis server

After finding the correct binary it will run a command similar to this to start
the server (where `nginx` is the path to the located OpenResty installation):

```bash
$ nginx -p "$(pwd)"/ -c "nginx.conf.compiled"
```


#### Cqueues Server

When using Cqueues & lua-http, no additional processes are created. Your server
is started directly inside of the Lapis command. After reading the
configuration model it will attempt to load a module called `app` to serve.

### `lapis migrate`

    Usage: lapis migrate [-h] [--migrations-module <module>]
           [<environment>] [--transaction [{global,individual}]]

    Run any outstanding migrations

    Arguments:
       environment

    Options:
       -h, --help            Show this help message and exit.
       --migrations-module <module>
                             Module to load for migrations (default: migrations)
       --transaction [{global,individual}]


This will run any outstanding migrations. The migrations table if it does not
exist yet. A database must be configured in the environment for this command to
work.

This command expects a `migrations` module as described in [Running
Migrations](database.html#database-migrations/running-migrations). The module
loaded can be overwritten with the `--migrations-module` flag.

It executes on the server approximately this code:

$dual_code{
moon = [[
import run_migrations from require "lapis.db.migrations"
run_migrations require "migrations"
]],
lua = [[
local migrations = require("migrations")
require("lapis.db.migrations").run_migrations(migrations)
]]
}

You can instruct the migrations to be run in a transaction by providng the
`--transaction` flag.

To wrap each individual migration in a transaction use:
`--transaction=individual`


### `lapis build`

```bash
$ lapis build [environment]
```

> This command is only available for OpenResty

Rebuilds the config. If the server is currently running then a `HUP` signal
will be sent to it. This causes the configuration to be reloaded. By default
Nginx does not see changes to the config file while it is running. By executing
`lapis build` you will tell Nginx to reload the config without having to
restart the server.

As a side effect all the Nginx workers are restarted, so your application code
is also reloaded.

This is the best approach when deploying a new version of your code to
production. You'll be able to reload everything without dropping any requests.

You can read more in the [Nginx manual](http://wiki.nginx.org/CommandLine#Loading_a_New_Configuration_Using_Signals).

### `lapis term`

> This command is only available for OpenResty

This will shut down a running server. This is useful if you've instructed Lapis
to start Nginx as a daemon. If you are running the server in the foreground you
can stop it using Ctrl-C.

It works by sending a TERM signal to the Nginx master process.

### `lapis simulate`

    Usage: lapis simulate [-h] [--app-class <app_class>]
           [--helper <helper>]
           [--method {GET,POST,PUT,DELETE,OPTIONS,HEAD,PATCH}]
           [--body <body>] [--form <form>] [--header <header>]
           [--host <host>] [--scheme <scheme>] [--json] [--csrf]
           [--print-headers] [--print-json] <path>

    Execute a mock HTTP request to your application code without any server involved

    Arguments:
       path                  Path to request, may include query parameters (eg. /)

    Request control:
       --method {GET,POST,PUT,DELETE,OPTIONS,HEAD,PATCH}
                             HTTP method (default: GET)
       --body <body>         Body of request, - for stdin
       --form <form>,        Set method to POST if unset, content type to application/x-www-form-urlencoded, and body to value of this option
           -F <form>
       --header <header>,    Append an input header, can be used multiple times (can overwrite set headers from other options
             -H <header>
       --host <host>         Set the host header of request
       --scheme <scheme>     Override default scheme (eg. https, http)
       --json                Set accept header to application/json
       --csrf                Set generated CSRF header and parameter for form requests

    Display options:
       --print-headers       Print only the headers as JSON
       --print-json          Print the entire response as JSON

    Other options:
       -h, --help            Show this help message and exit.
       --app-class <app_class>
                             Override default app class module name
       --helper <helper>     Module name to require before loading app



Examples:

```bash
# Request the root page with a GET request
lapis simulate /

# Request the login page with form data in a POST request, output response as JSON
lapis simulate /login --csrf --print-json -F username=bart -F password=cool
```

This command will load up your application in the current Lua run time, stub a
request object, and simulate a HTTP request to your application. (The request
is stubbed as if requested through the OpenResty server)

This command will execute the request in either the default environment or the
specified one. This is important to note if your request makes changes to the
database. The simulate commannd **does not** run in the *test* environment
unless explicitly specified.

By default the command will print information about the response, like the
status code and headers, to *stderr*, and the response body to *stdout*. The
output can be configured with flags like `--print-json` or `--print-headers`

When using the `--print-json` format option, if a session is set by the
request, it will be decoded into the json object for easy viewing.

### `lapis generate`

    Usage: lapis generate [-h] <template_name> [<args>] ...

    Generates a new file in the current directory from template

    Arguments:
       template_name         Which template to load (eg. model, flow, spec)
       template_args         Template arguments

    Options:
       -h, --help            Show this help message and exit.


The `generate` command can be used to create files in the current directory
based on templates that lapis includes. This can help simplify setting up an
initial app. The `lapis new` command internally calls a series of generators to
create the initial project.

#### `lapis generate rockspec`

Creates a LuaRocks rockspec file that can be used to manage the dependencies of the app.

    Usage: lapis generate rockspec [-h] [--app-name <app_name>]
           [--version-name <version_name>] [--moonscript] [--sqlite]
           [--postgresql] [--mysql]

    Generate a LuaRocks rockspec file for managing dependencies

    Dependencies:
       --moonscript, --moon  Include MoonScript as dependency
       --sqlite              Include SQLite dependencies
       --postgresql, --postgres
                             Include PostgreSQL dependencies
       --mysql               Include MySQL dependency

    Other options:
       -h, --help            Show this help message and exit.
       --app-name <app_name> The name of the app to use for the rockspec. Defaults to name of current directory
       --version-name <version_name>
                             Version of rockspec file to generate (default: dev-1)


As an example, to set up your app for using sqlite and MoonScript, you might run:

```bash
$ lapis generate rockspec --moonscript --sqlite
```

This wil create a new `.rockspec` file in the current directory, named after
the current directory. (You can rename name of the rockspec with `--app-name`)

You can then use LuaRocks to install the necessary dependencies, something like:

```bash
$ luarocks --local --lua-version=5.1 build --only-deps
```

If desired, you can lock your dependencies by version for the current project
by running something like:

```bash
$ luarocks --local --lua-version=5.1 build --only-deps --pin
```

> When pinning dependencies, a luarocks.lock file is created in the current
> directory. This should be checked into the repository. [Learn more about
> pinning versions with
> LuaRocks](https://github.com/luarocks/luarocks/wiki/Pinning-versions-with-a-lock-file)


#### `lapis generate migration`

    Usage: lapis generate migration ([--lua] | [--moonscript]) [-h]
           [--counter {timestamp,increment}]
           [--migrations-module <migrations_module>]

    Generate a migrations file if necessary, and append a new migration to the file

    Options:
       -h, --help            Show this help message and exit.
       --counter {timestamp,increment}
                             Naming convention for new migration (default: timestamp)
       --migrations-module <migrations_module>,
                  --module <migrations_module>
                             The module name of the migrations file (default: migrations)
       --lua                 Force editing/creating Lua file
       --moonscript, --moon  Force editing/creating MoonScript file


If a migrations file does not exist, `lapis generate migration` will create a
new migration file. It will then append a slot for a new migration to the end
of the file. By default, the new migration will be named with a unix timestamp.



