title: Creating a Lapis Application with Lua
--
<div class="override_lang" data-lang="lua"></div>

# Creating a Lapis Application with Lua

## Generating a New Project

If you haven't already, read through the [generic getting started guide][2] for
information on creating a new project skeleton along with details on OpenResty,
Nginx configurations, and the `lapis` command.

You can start a new project in the current directory busing by typing into your
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

app:get("/", function(self)
  return "Hello world"
end)

return app
```

Now we can start the server:

```bash
lapis server
```


Visit <http://localhost:8080> to see the page.

To change the port we can create a configuration. Create `config.lua`.

In this example we change the port in the `development` environment to 9090:

```lua
-- config.lua
local config = require "lapis.config"

config("development", {
  port = 9090
})
```

> You can read more about configurations on the [Configurations and
> Environments guide][3].

The `development` environment is used and loaded automatically when `lapis
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
local config = require("lapis.config").get()

local app = lapis.Application()

app:get("/", function(self)
  return config.greeting .. " from port " .. config.port
end)

return app
```

## Creating a View

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

app:get("/", function(self)
  return { render: "index" }
end)

return app
```

`etlua` is not enabled by default, you must enable it by calling the `enable`
method on your application instance.

We use the `render` parameter of our action's return value to instruct what
template to use when rendering the page. In this case `"index"` refers to the
module with the name `views.index`. `etalua` injects itself into Lua's
`require` method and so when the module `views.index` is loaded, an attempt to
read and parse the file `views/index.etlua` is made.

Running the server and navigating to it in the browser should show our rendered
template.

### Working with `etlua`

`etlua` comes with the following tags for injecting Lua into your templates:

* `<% lua_code %>` runs Lua code verbatim
* `<%= lua_expression %>` writes result of expression to output, HTML escaped
* `<%- lua_expression %>` same as above but with no HTML escaping


In the following example we assign some data in the action, then print it out
in our view:

```lua
-- my_app.lua
local lapis = require "lapis"

local app = lapis.Application()
app:enable("etlua")

app:get("/", function(self)
  self.my_favorite_things = {
    "Cats",
    "Horses",
    "Skateboards"
  }

  return { render: "list" }
end)

return app
```

```erb
<!-- views/list.etlua -->
<h1>Here are my favorite things</h1>
<ol>
  <% for i, thing in pairs() do %>
    <li><%= thing %></li>
  <% end %>
</ol>
```

### Creating a Layout

A layout is a separate shared template that wraps the content of every page.
Lapis comes with a basic layout to get you started but you'll most likely want
to create something custom.

We'll write the layout in etlua just like our views. Create `views/layout.etlua`:

```erb
<!-- views/layout.etlua -->
<!DOCTYPE HTML>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title><%= page_title or "My Page" %></title>
</head>
<body>
  <h1>Greetings</h1>
  <% content_for("inner") %>
</body>
</html>
```

The `content_for` function is a special function built into templates that
allows you to send data from a view to a layout. Lapis puts the rendered result
of the view into the content variable named `inner`. You'll note that we don't
need to use any of the etlua tags that write into the page. This is because
`content_for` efficiently puts its result directly into the output buffer.

Any other variables and helper functions that would normally be available in a
view are also available in the layout.

Now that the layout is written it can be assigned to the application:

```lua
local app = lapis.Application()
app:enable("etlua")
app.layout = require "views.layout"

-- the rest of the application...
```

The syntax is slightly different than rendering a view. Instead of assigning a
template name to the `layout` field, we assign the actual template object. This
can be obtained by just requiring it by the module name: `"views.layout"`. As
described above, etlua takes care of coverting the `.etlua` file into something
usable by Lua.


[1]: https://github.com/leafo/etlua
[2]: getting_started.html
[3]: configuration.html


