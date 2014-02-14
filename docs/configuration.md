
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


### Creating Configurations

Whenever Lapis starts the server it attempts to load the module `"config"`. If
it can't be found it is silently ignored. The `"config"` module is where we
define out configurations. It's a standard Lua/MoonScript file, so let's create
it.

```moon
-- config.moon
import config from require "lapis.config"

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

```moon
config {"development", "production"}, ->
  session_name "my_app_session"
```

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

```moon
config = require("lapis.config").get!
print config.port -- shows the current port
```

The name of the environment is stored in `_name`.

```moon
print config._name -- development, production, etc...
```

### Default Configuration

All configurations come with some default values, these are them in table
syntax:

```moon
default_config = {
  port: "8080"
  secret: "please-change-me"
  session_name: "lapis_session"
  num_workers: "1"
}
```

### Configuration Builder Syntax

Here's an example of the configuration DSL (domain specific language) and the
table it generates:

```moon
some_function = -> steak "medium_well"

config "development", ->
  hello "world"

  if 20 > 4
    color "blue"
  else
    color "green"

  custom_settings ->
    age 10
    enabled true

  -- tables are merged
  extra ->
    name "leaf"
    mood "happy"

  extra ->
    name "beef"
    shoe_size 12

    include some_function


  include some_function

  -- a normal table can be passed instead of a function
  some_list {
    1,2,3,4
  }

  -- use set to assign names that are unavailable
  set "include", "hello"
```

```moon
{
  hello: "world"
  color: "blue"

  custom_settings: {
    age: 10
    enabled: true
  }

  extra: {
    name: "beef"
    mood: "happy"
    shoe_size: 12
    steak: "medium_well"
  }

  steak: "medium_well"

  some_list: { 1,2,3,4 }

  include: "hello"
}
```

