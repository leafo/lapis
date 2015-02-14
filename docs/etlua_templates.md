title: etlua Templates
--

# `etlua` Templates

[`etlua`][1] is a templating language that lets you render the result of Lua
code inline in a template file to produce a dynamic output. In Lapis we use
`etlua` to render dynamic content inside of HTML templates.

`etlua` files use the `.etlua` extension. Lapis knows how to load those types
of files automatically using Lua's `require` function after you've enable
`etlua`

For example, here's a simple template that renders a random number:

```html
<!-- views/hello.etlua -->
<div class="my_page">
  Here is a random number: <%= math.random() %>
</div>
```

`etlua` comes with the following tags for injecting Lua into your templates:

* `<% lua_code %>` runs Lua code verbatim
* `<%= lua_expression %>` writes result of expression to output, HTML escaped
* `<%- lua_expression %>` same as above but with no HTML escaping


## Rendering From Actions

An *action* is a function that handles a request that matches a particular
route. An action should perform logic and prepare data before forwarding to a
view or triggering a render. Actions can control how the result is rendered by
returning a table of options.

The `render` option of the return value of an action lets us specify which
template to render after the action is executed. If we place an `.etlua` file
inside of the views directory, `views/` by default, then we can render a
template by name like so:


```lua
local lapis = require("lapis")

local app = lapis.Application()
app:enable("etlua")

app:match("/", function()
  return { render = "hello" }
end)

return app
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  @enable "etlua"
  "/": =>
    render: "hello"
```


Rendering `"hello"` will cause the module `"views.hello"` to load, which will
resolve our `etlua` template located at `views/hello.etlua`

Because it's common to have a single view for every (or most actions) you can
avoid repeating the name of the view when using a named route. A named route's
action can just set `true` to the `render` option and the name of the route
will be used as the name of the template:


```lua
local lapis = require("lapis")

local app = lapis.Application()
app:enable("etlua")

app:match("index", "/", function()
  return { render: true }
end)

return app
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  @enable "etlua"
  [index: "/"]: =>
    render: true
```

```html
<!-- views/index.etlua -->
<div class="index">
  Welcome to the index of my site!
</div>
```


### Passing Values to Views

Values can be passed to views by setting them on `self` in the action. For
example we might set some state for a template like so:


```lua
app:match("/", function(self)
  self.pets = { "Cat", "Dog", "Bird" }
  return { render = "my_template" }
end)
```

```moon
class App extends lapis.Application
  @enable "etlua"
  "/": =>
    @pets = {"Cat", "Dog", "Bird"}
    render: "my_template"
```

```html
<!-- views/my_template.etlua -->
<ul class="list">
<% for item in pets do %>
  <li><%= item %></li>
<% end %>
</ul>
```

You'll notice that we don't need to refer scope the values with `self` when
retrieving their values in the template. Any variables are automatically looked
up in that table by default.


## Calling Helper Functions from Views

Helper functions can be called just as if they were in scope when inside of a
template. A common helper is the `url_for` function which helps us generate a
URL to a named route:

```html
<!-- views/about.etlua -->
<div class="about_page">
  <p>This is a great page!</p>
  <p>
    <a href="<% url_for("index") %>">Return home</a>
  </p>
</div>
```

Any method available on the request object (`self` in an action) can be called
in the template. It will be called with the correct receiver automatically.

Additionally `etlua` templates have a couple of helper functions only defined in
the context of the template. They are covered below.


## Rendering Sub-templates

A sub-template is a template that is rendered inside of another template. For example
you might have a common navigation across many pages so you would create a
template for the navigation's HTML and include it in the templates that require
a navigation.

To render a sub-template you can use the `render` helper function:

```html
<!-- views/navigation.etlua -->
<div class="nav_bar">
  <a href="<% url_for("index") %>">Home</a>
  <a href="<% url_for("about") %>">About</a>
</div>
```

```html
<!-- views/index.etlua -->
<div class="page">
  <% render("views.navigation") %>
</div>
```

Note that you have to type the full module name of the template for the first
argument to require, in this case `"views.navigation"`, which points to
`views/navigation.etlua`. If you happen to also be using MoonScript templates
you can also include them using the `render` function.

Any values and helpers available in the parent template are also available in
the sub-template.

Somtimes you need to pass data to a sub-template that's generated during the
execution of the parent template. `render` takes a second argument of values
to pass into the sub-template.

Here's a contrived example of using a sub-template to render a list of numbers:

```html
<!-- templates/list_item.etlua -->
<div class="list_item">
  <%= number_value %>
</div>
```

```html
<!-- templates/list.etlua -->
<div class="list">
<% for i, value in ipairs({}) do %>
  <% render("templates.list_item", { number_value = value }) %>
<% end %>
</div>
```

## View Helper Functions

* `render(template_name, [template_params])` -- loads and renders a template
* `widget(widget_instance)` -- renders and instance of a `Widget`

[1]: https://github.com/leafo/etlua
