{
  title: "Server Backends"
}

# Server Backends

Lapis is a web framework, it does not provide an HTTP server implementation. A
separate server must be used. In order for Lapis to work with it it must know
how to communicate with it. Lapis supports the following servers:

* [OpenResty](http://openresty.org/en/)
* [cqueues](http://www.25thandclement.com/~william/projects/cqueues.html) and [lua-http](https://github.com/daurnimator/lua-http)

Lapis will only support servers that enable non-blocking IO transparently
through coroutines. You can learn more about what this means in
[http://leafo.net/posts/itchio-and-coroutines.html](http://leafo.net/posts/itchio-and-coroutines.html)


## Which Server to Use?

Lapis was originally designed for **OpenResty**. We've been running it in
production for many years with great success. It's stable, fast, and actively
developed.

Nginx, the server that OpenResty provides, is a great tool for a wide range of
things: serving static files, setting up a reverse proxy, security
configuration, rate limiting, scaling to multiple cores.

[OpenResty's Lua API](https://github.com/openresty/lua-nginx-module) provides a
handful of things that you may find useful as well: common hashing functions, a
system for asynchronous tasks, shared memory.

There are a few disadvantages: It can not be installed with LuaRocks, so you'll
need to install it manually. Additionally, Nginx requires a separate
configuration language.

**cqueues** is a recent addition. The main advantage is that it's a Lua
library, so you can install it with LuaRocks. It's easier to get started if you
have a working LuaRocks installation. It has a much more flexible event loop,
It doesn't provide many of the things that Nginx provides, so you'll have to
provide Lua based implementations. Additionally, at the moment Lapis only knows
how to run it on a single core.

### Can I switch between the two servers?

The Lapis API does not change depending on the server you're using, but Nginx
requires its own configuration file. If you instruct Nginx to do certain things
in that file then a Cqueues server will not be aware. In order to have server
swapping it's recommended to implement as much as your application in Lua using
Lapis APIs as possible.

## Specifying a Server

You can specify which server to use in your [configuration file]($root/reference/configuration.html):


```lua
local config = require("lapis.config")

config("development", {
  server = "cqueues"
})


```

```moon
-- config.moon
config = require "lapis.config"

config "development", ->
  server "cqueues"
```

