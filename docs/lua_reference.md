# Lapis Lua guide

## Creating an application

Start a new project in the current directory busing by typing into your
console:

```bash
$ lapis new --lua
```

The default `nginx.conf` reads a file called `web.lua` for your application.
Lets start by creating that.

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


## Creating a view

Now that we can create basic pages we'll likely want to render something a bit
more complex. Lapis comes with support for [etlua][1], an Lua templating
language that lets you insert Lua mixed in with text and HTML.

A view is a file that is responsible for generating the HTML. Typically your
action will prepare all the data for your view and then tell it to render.

By default Lapis searches for views in `views/` directory. Lets create a new
view there, `index.etlua`. We won't use any of etlua's special markup just yet,
so it will look like a normal HTML file.

```erb
<!-- views/index.etlua -->
<h1>Hello world</h1>
<p>Welcome to my page</p>
```

You'll notice that `<html>`, `<head>`, and `<body>` tags aren't there. The view
typically renders the inside of the page, and the layout is responsible for
what goes around it. We'll look at layouts further down.

Now lets create the application which renders our view:

```lua
-- my_app.lua
local lapis = require "lapis"
local app = lapis.Application()
app:enable("etlua")

app:get("/", function(req)
  return { render: "index" }
end)

return app
```

Before using `etlua` you have to enable is with the method call
`app:enable("etlua")`.


  [1]: https://github.com/leafo/etlua





