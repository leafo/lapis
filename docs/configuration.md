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
  lua_code_cache = "off"
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
  lua_code_cache "off"

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
* [Lua configuration syntax][0]

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
  num_workers = "1"
}
```

```moon
default_config = {
  port: "8080"
  secret: "please-change-me"
  session_name: "lapis_session"
  num_workers: "1"
}
```

