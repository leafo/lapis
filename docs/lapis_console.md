{
  title: "Lapis Console"
}
# Lapis Console

[Lapis Console][1] is a separate project that adds an interactive console to
your web application. Because Lapis runs inside of the Nginx loop, it's not
trivial to make a standard terminal based console that behaves the same way as
the web application. So a console that runs inside of your browser was created,
letting you reliably execute code in the same way as your web application when
debugging.

![Lapis Console Screenshot](http://leafo.net/dump/lapis_console.png "Screenshot of the Lapis Console exploring an object.")

Install through LuaRocks:

```bash
$ luarocks install lapis-console
```

## Creating A Console

### `console.make([opts])`

Lapis console provides an action that you can insert into your application to a
route of your choosing:


```lua
local lapis = require("lapis")
local console = require("lapis.console")

local app = lapis.Application()

app:match("/console", console.make())

return app
```


```moon
lapis = require "lapis"
console = require "lapis.console"

class extends lapis.Application
  "/console": console.make!
```

Now just head to to the `/console` location in your browser to use it. By
default the action that is created will only run in the `"development"`
environment.

You can set the `env` option in the first argument to `"all"` to enable in
every environment, or you can name an environment.

> Be careful about allowing access to the console, a malicious individual could
> destroy your application and compromise your system if given access.


## Tips

The console lets your write and execute a MoonScript program. Multiple lines
are supported.

The `print` function has been replaced in the console to print to the debug
output. You can print any type of object and the console will pretty print it.
Tables can be opened up and other types are color coded.

Any queries that execute during the script are logged to a special portion on
the bottom of the output.

`@` is equal to the value of the request that is initiating the console. You
can use this if you are testing a method that needs a request object.


[1]: https://github.com/leafo/lapis-console

