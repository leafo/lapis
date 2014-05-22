### Creating Configurations

Whenever Lapis starts the server it attempts to load the module `"config"`. If
it can't be found it is silently ignored. The `"config"` module is where we
define out configurations. It's a standard Lua/MoonScript file, so let's create
it.

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

```moon
config {"development", "production"}, ->
  session_name "my_app_session"
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

