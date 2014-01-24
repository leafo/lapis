# Lapis Lua Guide

## Creating An Application

Start a new project in the current directory busing by typing into your
console:

```bash
$ lapis new --lua
```

The default `nginx.conf` reads a file called `web.lua` for your application.
Let's start by creating that.

The job of `web.lua` is to load to serve our application. Typically your
application will be a separate Lua module defined in another file, so we just
need to reference it by name here:


```lua
-- web.lua
local lapis = require "lapis"
lapis.serve("my_app")
```

`lapis.serve` takes the name of the module that contains the application
that will handle the request. In our case we're using `"my_app"` so we'll
create `my_app.lua`:

```lua
-- my_app.lua
local lapis = require "lapis"

local app = lapis.Application()

app:get("/", function(req)
  return "Hello world"
end)

return app
```

Now we can start the server:

```bash
lapis server
```


Visit <http://localhost:8080> to see the page. To change the port we can create
a configuration. Create `config.lua`.

In this example we change the port in the `development` environment to 9090. 

```lua
-- config.lua
local config = require "lapis.config"

config("development", {
  port = 9090
})
```

The `development` environment is what is loaded automatically when `lapis
server` is run with no additional arguments. (And `lapis_environment.lua`
doesn't exist)


You can store anything you want in the configuration. For example:

```lua
-- config.lua
local config = require "lapis.config"

config("development", {
  greeting = "Hello world"
})
```

You can get the current configuration by calling `get`. It returns a plain Lua
table:

```lua
-- my_app.lua
local lapis = require "lapis"
local config = require("lapis.config").get!

local app = lapis.Application()

app:get("/", function(req)
  return config.greeting .. " from port " .. config.port
end)

return app
```




