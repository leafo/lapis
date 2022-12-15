{
  title: "etlua Templates"
}
# `etlua` Templates

[`etlua`][1] is a templating language that lets you render the result of Lua
code inline in a template file to produce a dynamic output. In Lapis we use
`etlua` to render dynamic content inside of HTML templates.

`etlua` files use the `.etlua` extension. Lapis knows how to load those types
of files automatically using Lua's `require` function after you've enabled
`etlua`

For example, here's a simple template that renders a random number:

```erb
<!-- views/hello.etlua -->
<div class="my_page">
  Here is a random number: <%= math.random() %>
</div>
```

`etlua` comes with the following tags for injecting Lua into your templates:

* `<% lua_code %>` -- runs Lua code verbatim. If the code is an expression then the result is ignored
* `<%= lua_expression %>` -- writes result of expression to output, HTML escaped
* `<%- lua_expression %>` -- writes result of expression to output, **with no HTML escaping**. See [Security Considerations](#security-considerations)


## Security Considerations

If you are rendering user-provided data in your views then you must take
special care to escape the data when rendering it to prevent cross-site
scripting attacks.

If a malicious user is able to inject JavaScript or other unapproved markup
into your page then they may be able to comprise your platform for other users,
including stealing sessions or performing unapproved authenticated actions.

The etlua tag `<%= lua_expression %>` will HTML escape the output such that it
is suitable for use in the content or attributes of an HTML tag.

In some cases it may be cumbsome to use `<%= lua_expression %>` in multiple
places when constructing HTML elements. The `element` function can be used to
write a tag to the buffer programatically in Lua code, and it will
automatically escape any values passed to it.

In this example the `element` function is used to generate the link to the
user, with the username and URL correctly escaped.

```erb
<ul class="list">
  <% for i, user in ipairs(users) do %>
    <li>
      <% element("a", { href: url_for(user) }, user:get_display_name()) %>
    </li>
  <% end %>
</ul>
```

Notice how `element` uses `<% %>` etlua tags. `element` does not return any
value, but instead writes directly to the buffer.

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
  return { render = true }
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

```erb
<!-- views/my_template.etlua -->
<ul class="list">
<% for i, item in ipairs(pets) do %>
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

```erb
<!-- views/about.etlua -->
<div class="about_page">
  <p>This is a great page!</p>
  <p>
    <a href="<%= url_for("index") %>">Return home</a>
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

```erb
<!-- views/navigation.etlua -->
<div class="nav_bar">
  <a href="<%= url_for('index') %>">Home</a>
  <a href="<%= url_for('about') %>">About</a>
</div>
```

```erb
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

Sometimes you need to pass data to a sub-template that's generated during the
execution of the parent template. `render` takes a second argument of values
to pass into the sub-template.

Here's a contrived example of using a sub-template to render a list of numbers:

```erb
<!-- templates/list_item.etlua -->
<div class="list_item">
  <%= number_value %>
</div>
```

```erb
<!-- templates/list.etlua -->
<div class="list">
<% for i, value in ipairs({}) do %>
  <% render("templates.list_item", { number_value = value }) %>
<% end %>
</div>
```

## `etlua` template functions

The following functions are globally available in any `etlua` template loaded
by Lapis to be used as a view.

* `render(template_name, [template_params])` -- loads and renders a template to the buffer
* `widget(widget_instance)` -- renders and instance of a `Widget` to the buffer
* `element(name, ...)` -- renders an HTML element to the buffer with `name`, supporting the full HTML builder syntax for any nested functions

Note that when a helper renders to the buffer, there will be no return value.
It is not necessary to use an etlua tag that will take print the output of the
function.

## `EtluaWidget` reference

Lapis transparently converts `.etlua` files to `EtluaWidget`s when you request
them to be used as a template (after enabling `etlua`). You can manually
compile template code programatically by interacting directly with the
`EtluaWidget` class.

It is not necessary to *enable* `etlua` if you are using the `EtluaWidget`
class directly. Instances of the `EtluaWidget` implement the *render* interface
necessary to be used in any place Lapis expects a template or view.

Note that `etlua` templates are *compiled* to enable them to render at the
highest possible performance. You should avoid compiling templates (eg.
`EtluaWidget:load()`) during every request or it may have a negative impact on
your performance. Cache the result as a Lua module or somewhere where it can
persist between requests.

### `EtluaWidget:load(template_code)`

The `load` method takes a etlua template string, compiles it and creates a new
`EtluaWidget` class that can be used to render the template with parameters.

$dual_code{
moon = [==[
import EtluaWidget from require "lapis.etlua"

widget = EtluaWidget\load [[
  <h1>Hello <%= username %></h1>
]]

widget(username: "Garf")\render_to_string!
]==],
lua = [==[
local etlua = require("lapis.etlua")

local widget = etlua.EtluaWidget:load [[
  <h1>Hello <%= username %></h1>
]]

widget({ username =  "Garf" }):render_to_string()
]==]}

### `EtluaWidget([opts])`

The default constructor of the widget class will copy every field from the
`opts` argument to `self`, if the `opts` argument is provided. Values on `self`
will be available in scope for the template when it is rendered.

### `etluawidget:render_to_string()`

Renders the template and returns the string result. This will automatically
create a temporary buffer for the duration of the render.

### `etluawidget:render(buffer, ...)`

Renders the template to the provided buffer. Under normal circumstances it is
not necessary to use this method directly.

This method returns nothing.

[1]: https://github.com/leafo/etlua
