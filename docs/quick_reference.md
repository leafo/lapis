{
  title: "Quick Reference"
}

Although Lapis has comprehensive documentation, it might be hard to find a
specific thing if you don't know where to look. Here are some commonly asked
questions organized on a single page suitable for searching.

> All of these questions can easily be navigated to from the in-documentation
> search bar

If there's a question that you think belongs here please open an issue on the
[issues tracker](https://github.com/leafo/lapis/issues).

## How do I read an HTTP header?

The `req` field of the `self` passed to actions has a `headers` field with all
the request headers. They are normalized so you don't have to be concerned
about capitalization.

$dual_code{
lua = [[
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self)
  return self.req.headers["referer"]
end)
]],
moon = [[
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
    @req.headers["referer"]
]]
}

## How do I write an HTTP header?

There are two ways to write headers. In these examples we set the
`Access-Control-Allow-Origin` header to `*`

You can return a headers field (or pass it to `write`) from an action:

$dual_code{
lua = [[
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self)
  return {
    "ok",
    headers = {
      ["Access-Control-Allow-Origin"] = "*"
    }
  }
end)
]],
moon = [[
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
    "ok", {
      headers: {
        "Access-Control-Allow-Origin": "*"
      }
    }
]]
}

Alternatively, the `res` field of the `self` has a `headers` field that lets
you set headers.

$dual_code{
lua = [[
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self)
  self.res.headers["Access-Control-Allow-Origin"] = "*"
  return "ok"
end)
]],
moon = [[
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
    @res.headers["Access-Control-Allow-Origin"] = "*"
    "ok"
]]
}

If you need to change the content type see below.

## How do I set the content type?

Either manually set the header as described above, or use the `content_type`
option of the `write` method, or action return value:

$dual_code{
lua = [==[
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self)
  return { content_type = "text/rss", [[<rss version="2.0"></rss>]] }
end)
]==],
moon = [==[
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
    [[<rss version="2.0"></rss>]], content_type: "text/rss"
]==]
}


## How do I render JSON?

Use the `json` option of the `write` method, or the action's return value:

$dual_code{
lua = [[
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self)
  return {
    json = {
      success = true,
      message = "hello world"
    }
  }
end)
]],
moon = [[
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
    {
      json: {
        success: true
        message: "hello world"
      }
    }
]]
}

## How can I read JSON HTTP body?

By default Lapis will only parse form-encoded request bodies. You can extract a
json encoded request body by using the `json_params` action decorator function.
The values are placed into `params`.

$dual_code{
lua = [[
local lapis = require("lapis")
local json_params = require("lapis.application").json_params

local app = lapis.Application()

app:match("/json", json_params(function(self)
  return self.params.value
end))
]],
moon = [[
lapis = require "lapis"
import json_params from require "lapis.application"

class App extends lapis.Application
  "/json": json_params =>
    @params.value
]]
}

The `application/json` content type must be included in order for the data to
be extracted.

```bash
$ curl \
  -H "Content-type: application/json" \
  -d '{"value": "hello"}' \
  'http://localhost:8080/json'
```

## How do I respond to GET, POST, DELETE or other HTTP verbs?

The `respond_to` action decorator function gives a basic framework for running
different code depending on the HTTP method.

> `try_to_login` is a hypothetical function, and not regularly globally
> available

$dual_code{
lua = [[
local lapis = require("lapis")
local app = lapis.Application()
local respond_to = require("lapis.application").respond_to

app:match("/login", respond_to({
  -- do common setup
  before = function(self)
    if self.session.current_user then
      self:write({ redirect_to = "/" })
    end
  end,
  -- render the view
  GET = function(self)
    return { render = true }
  end,
  -- handle the form submission
  POST = function(self)
    self.session.current_user =
      try_to_login(self.params.username, self.params.password)

    return { redirect_to = "/" }
  end
}))
]],
moon = [[
lapis = require "lapis"
import respond_to from require "lapis.application"

class App extends lapis.Application
  "/login": respond_to {
    before: =>
      -- do common setup
      if @session.current_user
        @write redirect_to: "/"

    GET: =>
      -- render the view
      render: true

    POST: =>
      -- handle the form submission
      @session.current_user = try_to_login(@params.username, @params.password)
      redirect_to: "/"
  }
]]
}

## How do I restart a running server, or reload the code?

Once the server is started, you can use the `lapis term` command from your
command line to stop the server.

If you're deploying new code, then you can hot-reload the code without any
downtime using the `lapis build` command. Before reloading, `lapis build`
validates the new config with `nginx -t` and refuses to reload if it's invalid,
so a broken config can't be silently swallowed by the running server.

## How do I disable the stack trace on the error page?

By default Lapis will print the stack trace for any server errors. You can
prevent this from happening by overriding the `handle_error` method on your
application:

$dual_code{
lua = [[
local lapis = require("lapis")
local app = lapis.Application()

function app:handle_error(err, trace)
  -- log err and trace somewhere before returning a response
  return { status = 500, layout = false, "There was an error" }
end
]],
moon = [[
lapis = require "lapis"

class App extends lapis.Application
  handle_error: (err, trace) =>
    -- log err and trace somewhere before returning a response
    status: 500, layout: false, "There was an error"
]]
}

See [`handle_error`](actions.html#application-configuration/callbacks/application:handle_error)
for more details.

## What versions of Lua are supported?

Lapis is tested against Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT. The default server
is OpenResty, which is tied to LuaJIT (which is a hybrid version of Lua 5.1).
When installing Lapis to use with OpenResty, make sure you install it for Lua
5.1 with `luarocks --lua-version=5.1`.

## How do I handle multiple domains and subdomains?

Lapis doesn't make any distinction between domains and subdomains. With
OpenResty you can use Nginx configuration `location` blocks to identify
different domains. Within the matched block you can execute the desired Lapis
application.

## How can I read the entire body of the request?

Call the `read_body_as_string` method on the `req` field of the request object.
It returns the body as a string, or `nil` if there's no body:

$dual_code{
lua = [[
app:post("/webhook", function(self)
  local body = self.req:read_body_as_string()
  -- ...
end)
]],
moon = [[
class App extends lapis.Application
  "/webhook": =>
    body = @req\read_body_as_string!
    -- ...
]]
}

In OpenResty, request bodies larger than the
[`client_body_buffer_size`](https://nginx.org/en/docs/http/ngx_http_core_module.html#client_body_buffer_size)
directive are written to a temporary file instead of memory, and
`read_body_as_string` will return `nil`. Increase `client_body_buffer_size` if
you need to read larger bodies. Streaming large bodies requires using the
server specific interface.
