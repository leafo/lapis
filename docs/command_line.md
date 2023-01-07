{
  title: "Command Line Interface"
}
# Command Line Interface


## Default Environment

Lapis will load your app's configuration by the environment name before
executing a command. The default environment name is *development* unless you
are running within *Busted*, then the default environment name is *test*.

You are free to use any environment name you want. You can change the default
environment in a few different ways:

* Using the `--environment` flag on the `lapis` command will set the environment for the duration of the command
* For convenience, some commands can also take the environment as an argument after the command name, eg `lapis serve production` (This will have the same effect as using `--environment`
* Created a `lapis_environment.lua` file in your working directory that returns a string of the default environment's name


For example, if you have a production deployment, you might add the following file:

$dual_code{
lua = [[
-- lapis_environment.lua
return "production"
]],
moon = [[
-- lapis_environment.moon
return "production"
]],
}


## Command Reference

### `lapis new`

```
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
```

The `new` command will create a blank Lapis project in the current directory by
writing some starter files. Note that it is not necessary to use `lapis new` to
create a new Lapis project, you're free to start with just a single Lua file.

By default it creates the following files:

* `nginx.conf`
* `mime.types`
* `app.lua`

> Use the `--moonscript` flag to generate a blank MoonScript based app

You're encouraged to look at all of these files and customize them to your
needs.

### `lapis server`

```bash
$ lapis server [environment]
```

This command is a wrapper around starting OpenResty. It firsts builds the
config, ensures logs exist, then starts the sever with the correct environment.

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

### `lapis build`

```bash
$ lapis build [environment]
```

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

### `lapis migrate`

```bash
$ lapis migrate [environment]
```

This will run any outstanding migrations. It will also create the migrations
table if it does not exist yet.

This command expects a `migrations` module as described in [Running
Migrations](database.html#database-migrations/running-migrations).

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

### `lapis term`

This will shut down a running server. This is useful if you've instructed Lapis
to start Nginx as a daemon. If you are running the server in the foreground you
can stop it using Ctrl-C.

It works by sending a TERM signal to the Nginx master process.
