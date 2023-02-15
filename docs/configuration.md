{
  title: "Configuration and Environments"
}
# Configuration and Environments

Lapis is designed to run your server in different configurations called
environments. For example you might have a development configuration with a
local database URL, code caching disabled, and a single worker. Then you might
have a production configuration with remote database URL, code caching enabled,
and 8 workers.

The `lapis` command line tool takes a second argument when starting the server:

```bash
$ lapis server [environment]
```

## Default Environment

The default environment is used when you don't explicitly specify an
environment. The following conditions are checked in order to determine the
default environment:

1. When inside a of a test suite (supported environments: [Busted](http://olivinelabs.com/busted/)), the default environment is set to `test`
2. When a module named `lapis_environment` exists, the return value of that module is used as the default environment
3. Otherwise, default environment is set to `development`

The default environment affects what configuration is loaded by default. The
environment name has no effect unless you are working with configurations.

> Database connections use the configurations to determine how to connect to
> the database, so you'll often use different environments to connect to
> different databases.

### Overriding The Default Environment

You can override the default environment by setting a `LAPIS_ENVIRONMENT`
environment variable on your system before executing any Lapis code.

Some `lapis` commands also let you explicitly set the environment to override
the default.

## Creating Configurations

Whenever Lapis executes code that depends on a configuration it attempts to
load the module `"config"`.  The `"config"` module is where we define our
environment specific variables. It's a standard Lua/MoonScript file.

> If the `config` module is not found no error is thrown, and only the default
> configuration is available.

```lua
local config = require("lapis.config")

config("development", {
  port = 8080
})

config("production", {
  port = 80,
  num_workers = 4,
  code_cache = "on"
})

```

```moon
-- config.moon
config = require "lapis.config"

config "development", ->
  port 8080

config "production", ->
  port 80
  num_workers 4
  code_cache "on"

```

We use the configuration helpers provided in `"lapis.config"` to create our
configurations. This defines a domain specific language for setting variables.
In the example above we define two configurations, and set the ports for each
of them.

A configuration is just a plain table. Use the special builder syntax above to
construct the configuration tables.

We can configure multiple environments at once by passing in an array table for
environment names:

```lua
config({"development", "production"}, {
  session_name = "my_app_session"
})
```

```moon
config {"development", "production"}, ->
  session_name "my_app_session"
```

The configuration file has access to a nice syntax for combining nested
tables. Both MoonScript and Lua have their own variations, for more details
about the syntax have a look at the respective guide.

* [MoonScript configuration syntax][0]
* [Lua configuration syntax][1]


## Built-in Configuration

Although most configuration keys are free for any use, some names are reserved
for controlling how Lapis and supporting libraries work. Keep in mind some
configurations are only used depending on the server.

> For your app's configuration, you can avoid future conflicts by scoping your
> configuration values to your app's name.

$config_table{
  {
    name = "server",
    default = '`"nginx"`',
    description = "The server your code will run in. Either `nginx` or `cqueues`"
  },
  {
    name = "port",
    default = "`8080`",
    description = [[
      The port your server will bind to
    ]]
  },
  {
    name = "bind_host",
    default = '`"0.0.0.0"`',
    description = "The interface the server will bind to",
    servers = {"cqueues"}
  },
  {
    name = "secret",
    default = '`"please-change-me"`',
    description = "The secret string used to sign sessions and tokens"
  },
  {
    name = "hmac_digest",
    default = '`"sha1"`',
    description = [[Controls the hashing function used for HMAC sessions and signed strings. One of `"sha1"`, `"sha256"`.]]
  },
  {
    name = "session_name",
    default = '`"lapis_session"`',
    description = "Name of cookie used to store the [session]($root/reference/actions.html#request-object-session)"
  },
  {
    name = "code_cache",
    default = '`"off"`',
    description = [[
      Controls if code is cached across requests, or is reloaded for each request.

      One of `"on"` or `"off"`. Production servers should enable code caching for maximum performance.
    ]]
  },
  {
    name = "num_workers",
    default = "`1`",
    description = [[
      How many worker processes to spawn to handle requests. See
      [worker_processes](http://nginx.org/en/docs/ngx_core_module.html#worker_processes).
    ]],
    servers = {"nginx"}
  },
  {
    name = "logging",
    description = "A table of loggers to enable, or `false` to disable all logging", 
    default = "See below"
  },
  {
    name = "max_request_args",
    description = [[
      Controls the maximum number of query and post parameters parsed from request.
      See `max_args` in [get_uri_args](https://github.com/openresty/lua-nginx-module#ngxreqget_uri_args).
    ]],
    servers = {"nginx"}
  },
  {
    name = "measure_performance",
    default = '`false`',
    description = "Enables per-request performance metric collection, see [Performance Measurement](#performance-measurement)."
  }, 
  {
    name = "postgres",
    description = "PostgreSQL connection settings",
    default = "[*See PostgreSQL docs*](database.html)"
  },
  {
    name = "mysql",
    description = "MySQL connection settings",
    default = "[*See MySQL docs*](database.html)"
  },
  {
    name = "sqlite",
    description = "SQLite connection settings"
  }
}


### Logging configuration

Logging configuration is stored in a table under the name `logging` in the
global configuration. If the value is set to `false` then all logging is
disabled.

> This only controls logging done by Lapis, server specific logging in
> OpenResty is controlled with the nginx config file.

$config_table{
  {
    name = "server", 
    default = "`true`",
    description = "Show server start message",
    servers = {"cqueues"}
  },
  {
    name = "queries", 
    default = "`true`",
    description = "Show queries sent to database"
  },
  {
    name = "requests", 
    default = "`true`",
    description = "Show path and status for every request"
  }
}

For OpenResty, all logging is done to Nginx's notice log using the `print`
function provided by OpenResty. The default notice logging location is set to
`stderr`, specified in the default Lapis Nginx configuration. It can be configured
using the [`error_log`
directive](http://nginx.org/en/docs/ngx_core_module.html#error_log).

Otherwise, logs are written to standard out using Lua's `print` function.

## Configurations and Nginx

The values in the configuration are used when compiling `nginx.conf`.
Interpolated Nginx configuration variables are case insensitive. They are
typically written in all capitals because the shell's environment is checked
for a value before the configuration is checked.

For example, here's a chunk of an Lapis Nginx configuration:

```nginx
events {
  worker_connections ${{WORKER_CONNECTIONS}};
}
```

## Overriding With Environment Variables

You can override any configuration value with an environment variable. Prefix
the configuration name with `LAPIS_` and make the rest of the name all
uppercase. For example, to override the `worker_connections` variable:

```bash
$ LAPIS_WORKER_CONNECTIONS=5 lapis server
```

This can be used with any configuration variable. Keep in mind that the value
will always be a string type, so you may need to add additional type coercion
to you code that reads it.

## Accessing Configuration From Application

The configuration is also made available in the application. We can get access
to the configuration table like so:

```lua
local config = require("lapis.config").get()
print(config.port) -- shows the current port
```


```moon
config = require("lapis.config").get!
print config.port -- shows the current port
```

The name of the environment is stored in `_name`.

```lua
print(config._name) -- development, production, etc...
```

```moon
print config._name -- development, production, etc...
```
## Performance Measurement

Lapis can collect timings and counts for various actions if the
`measure_performance` configuration value is set to true.

The data is stored in `ngx.ctx.performance`. The following fields are collected
in a table:

* `view_time` -- Time in seconds spent rendering view
* `layout_time` -- Time in seconds spent rendering layout
* `db_time` -- Time in seconds spent executing queries
* `db_count` -- The number of queries executed
* `http_time` -- Time in seconds spent executing HTTP requests
* `http_count` -- The number of HTTP requests sent

A field will be `nil` if no corresponding action was done in the request. The
fields are filled out over the course of the request so it's best to only access
them at the very end of the request to ensure all the data is available. The
`after_dispatch` helper can be used to register a function to run at the very
end of processing a request.

In this example the performance data is printed to the log at the end of every
request:


```lua
local lapis = require("lapis")
local after_dispatch = require("lapis.nginx.context").after_dispatch
local to_json = require("lapis.util").to_json

local config = require("lapis.config")

config("development", {
  measure_performance = true
})


local app = lapis.Application()

app:before_filter(function(self)
  after_dispatch(function()
    print(to_json(ngx.ctx.performance))
  end)
end)

-- ...

return app

```


```moon
lapis = require "lapis"
import after_dispatch from require "lapis.nginx.context"
import to_json from require "lapis.util"

config = require "lapis.config"
config "development", ->
  measure_performance true

class App extends lapis.Application
  @before_filter =>
    after_dispatch ->
      print to_json(ngx.ctx.performance)

  -- ...
```

[0]: $root/reference/moon_creating_configurations.html
[1]: $root/reference/lua_creating_configurations.html

