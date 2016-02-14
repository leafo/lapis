{
  title: "Command Line Interface"
}
# Command Line Interface

## Command Reference

The Lapis command line interface gives you a couple of handful tools for
working with Lapis projects.

For any commands that require an environment as an argument, if no environment
is specified then the default environment is used. If the file
`lapis_environment.lua` exists in the directory, then the return value of that
file will be used, otherwise it is `development`.

For example, if you have a production deployment, you might add the following file:

```lua
-- lapis_environment.lua
return "production"
```

### `lapis new`

```bash
$ lapis new [--git] [--tup] [--lua]
```

The `new` command will create a blank Lapis project in the current directory.
By default it creates the following files:

* `nginx.conf`
* `mime.types`
* `app.moon`

You're encouraged to look at all of these files and customize them to your
needs.

You can tell it to generate additional files using the following flags:

`--git` generates a `.gitignore` file containing the following:

    *.lua
    logs/
    nginx.conf.compiled

`--tup` -- generates `Tupfile` and `Tuprules.tup` for use with
[Tup](http://gittup.org/tup/) build system. The rules file contains a rule for
building MoonScript files to Lua.

`--lua` -- generates a skeleton Lua app instead of MoonScript.

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

```moon
import run_migrations from require "lapis.db.migrations"
run_migrations require "migrations"
```

### `lapis term`

This will shut down a running server. This is useful if you've instructed Lapis
to start Nginx as a daemon. If you are running the server in the foreground you
can stop it using Ctrl-C.

It works by sending a TERM signal to the Nginx master process.
