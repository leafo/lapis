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
    Lapis: 1.12.0
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
       build                 Rebuild configuration and send a reload signal (server: nginx)
       term                  Sends TERM signal to shut down a running server (server: nginx)
       exec, execute         Execute Lua on the server (server: nginx)
       migrate               Run any outstanding migrations
       generate              Generates a new file in the current directory from template

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
           [-h] [--etlua-config] [--git] [--tup]

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
