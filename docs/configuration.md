
## Configuration and Environments

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


### Configurations and Nginx

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

### Accessing Configuration From Application

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

### Default Configuration Values

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

