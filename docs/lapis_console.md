{
  title: "Lapis Console"
}
# Lapis Console

[Lapis Console][1] is a separate project that adds an interactive console to
your web application. The console runs inside of your browser and executes
code on the server as part of a request, so the code runs in the same
environment as your web application. This makes it useful for debugging and
for exploring your models and data.

![Lapis Console Screenshot](https://leafo.net/dump/lapis_console.png "Screenshot of the Lapis Console exploring an object.")

Install through LuaRocks:

```bash
$ luarocks install lapis-console
```

> If you only need to run a snippet of code on the server from the command
> line, see [`lapis exec`](command_line.html#command-reference/lapis-exec).

## Creating A Console

### `console.make([opts])`

Lapis console provides an action that you can insert into your application to a
route of your choosing:

$dual_code{
lua = [[
local lapis = require("lapis")
local console = require("lapis.console")

local app = lapis.Application()

app:match("/console", console.make())

return app
]],
moon = [[
lapis = require "lapis"
console = require "lapis.console"

class extends lapis.Application
  "/console": console.make!
]]
}

Now head to the `/console` location in your browser to use it. By default the
action that is created will only run in the `"development"` environment, and
will return a 404 in any other environment.

You can set the `env` option in the first argument to `"all"` to enable it in
every environment, or you can name an environment.

> Be careful about allowing access to the console. The code that runs is not
> restricted in any way, and a malicious individual could destroy your
> application and compromise your system if given access.

## Tips

Code can be written in either MoonScript or Lua, selectable from the dropdown
next to the run button. The editor supports multiple lines, and code is run
with Ctrl+Enter (Cmd+Enter on macOS).

Any values returned by the code are shown in the result. MoonScript returns
the value of the last expression, so you can type an expression like
`Users\find 1` without wrapping it in `print`. In Lua, use `return`.

The `print` function has been replaced in the console to print to the output.
You can print any type of object and the console will pretty print it. Tables
can be opened up and other types are color coded.

Any queries that execute during the code are logged along with the result. The
time taken by each query is shown when the `measure_performance`
[configuration](configuration.html) value is enabled.

If the code throws an error, anything printed before the error is still shown,
along with the stack trace.

`self` (`@` in MoonScript) is equal to the request object that is running the
console. You can use this if you are testing a method that needs a request
object.

Each result shows the code that produced it. Click it to load the code back
into the editor. Previous runs can also be browsed by pressing up on the first
line of the editor, and down on the last line.

[1]: https://github.com/leafo/lapis-console
