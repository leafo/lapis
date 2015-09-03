title: Configuration and Environments
--
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

By default the environment is `development`. The environment name only affects
what configuration is loaded. This has absolutely no effect if you don't have any
configurations, so let's create some.

## Creating Configurations

Whenever Lapis executes code that depends on a configuration it attempts to
load the module `"config"`.  The `"config"` module is where we define our
environment specific variables. It's a standard Lua/MoonScript file, so let's
create it.

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
evironment names:

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

When this is compiled, first the environment variable
`LAPIS_WORKER_CONNECTIONS` is checked. If it doesn't have a value then the
configuration of the current environment is checked for `worker_connections`.

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

## Default Configuration Values

All configurations come with some default values, these are them in table
syntax:


```lua
default_config = {
  port = "8080",
  secret = "please-change-me",
  session_name = "lapis_session",
  num_workers = "1",
  logging = {
    queries = true,
    requests = true
  }
}
```

```moon
default_config = {
  port: "8080"
  secret: "please-change-me"
  session_name: "lapis_session"
  num_workers: "1"
  logging: {
    queries: true
    requests: true
  }
}
```


## Available Configuration Values

Althought most coniguration keys are free for any use, some names are reserved
for configuring Lapis and supporting libraries. Here is a list of them:

* `port` (`number`) -- The port of Nginx, defined in default `nginx.conf`
* `num_workers` (`number`) -- The number of workers to launch for Nginx, defined in default `nginx.conf`
* `session_name` (`string`) -- The name of the cookie where the [session]($root/reference/actions.html#request-object-session) will be stored
* `secret` (`string`) -- Secret key used by `encode_with_secret`, also used for signing session cookie
* `measure_performance` (`bool`) -- Used to enable performance time and query tracking
* `logging` (`table`) -- Configure which events to log to console or log files


## Configuring Logging

The `logging` configuration key can be used to disable the various logging that
Lapis does by default. The default value of the logging configuration is:

```lua
{
  queries = true,
  requests = true
}
```

```moon
{
  queries: true
  requests: true
}
```

All logging is done to Nginx's notice log using the `print` function provided
by OpenResty. The default notice logging location is set to `stderr`, specified
in the default Lapis Nginx configuration. It can configured using the
[`error_log`
directive](http://nginx.org/en/docs/ngx_core_module.html#error_log).

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

