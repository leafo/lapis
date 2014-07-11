title: etlua Templates
--

# `etlua` Templates

[`etlua`][1] is a templating language that lets you render the result of Lua
code inline a file to produce a dynamic output. In Lapis we use `etlua` to
render dynamic content inside of HTML templates.

`etlua` files use the `.etlua` extension. Lapis knows how to load those types
of files automatically using Lua's `require` function after you've enable
`etlua` 

For example, here's a simple template that renders a random number:

```erb
<!-- views/hello.etlua -->
<div class="my_page">
  Here is a random number: <%= math.random() %>
</div>
```

`etlua` comes with the following tags for injecting Lua into your templates:

* `<% lua_code %>` runs Lua code verbatim
* `<%= lua_expression %>` writes result of expression to output, HTML escaped
* `<%- lua_expression %>` same as above but with no HTML escaping


## Rendering from action

The `render` option of the return value of an action lets us specify which
template to render after the action is executed. If we place an `.etlua` file
inside of the views directory, `views/` by default, then we can render a
template by name like so:


```lua
local lapis = require("lapis")

local app = lapis.Application()
app:enable("etlua")

app:match("/", function()
  return { render: "hello" }
end)

reutrn app
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  @enable "etlua"
  "/": => render: "hello"
```


Rendering `"hello"` will cause the module `"views.hello"` to load, which will
resolve our `etlua` template located at `views/hello.etlua`


## Rendering sub-templates


[1]: https://github.com/leafo/etlua
