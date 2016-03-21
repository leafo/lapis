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

## How do I read a HTTP header?

The `req` field of the `self` passed to actions has a headers fields with all
the request headers. They are normalized so you don't have to be concerned
about capitalization.

```lua
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self)
  return self.req.headers["referrer"]
end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
    @req.headers["referrer"]
```

## How do I write a HTTP header?

The `res` field of the `self` has a `headers` field that lets you set headers.
Here's how you would set the `Content-type` header:

```lua
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self)
  self.res.headers["Access-Control-Allow-Origin"] = "*"
  return "ok"
end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
    @res.headers["Access-Control-Allow-Origin"] = "*"
    "ok"
```

If you need to change the content type see below.

## How do I set the content type?

Either manually set the header as described above, or use the `content_type`
option of the `write` method, or action return value:

```lua
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self)
  return { content_type: "text/rss", "<rss version="2.0"></rss>" }
end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
    "<rss version="2.0"></rss>", content_type: "text/rss"
```


## How to do I render JSON?

Use the `json` option of the `write` method, or the action's return value:

```lua
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self)
  return {
    json: {
      success: true
      message: "hello world"
    }
  }
end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
    {
      json: {
        success: true
        message: "hello world"
      }
    }
```

## How can I read JSON HTTP body?

By default Lapis will only parse form-encoded request bodies. You can extract a
json encoded request body by using the `json_params` action decorator function.
The values are placed into `params`.

```lua
local json_params = require("lapis.application").json_params

app:match("/json", json_params(function(self)
  return self.params.value
end))
```

```moon
lapis = require "lapis"
import json_params from require "lapis.application"

class App extends lapis.Application
  "/": json_params =>
    @params.value
```

The `application/json` content type must be included in order for the data to
be extracted.

```bash
$ curl \
  -H "Content-type: application/json" \
  -d '{"value": "hello"}' \
  'https://localhost:8080/json'
```

## How do I respond to GET, POST, DELETE or other HTTP verbs?

The `respond_to` action decorator function gives a basic framework for running
different code depending on the HTTP method.

> `try_to_login` is a hypothetical functions, and not regularly globally
> available

```lua
local lapis = require("lapis")
local app = lapis.Application()
local respond_to = require("lapis.application").respond_to

app:match("/", respond_to({
  before = function(self)
    if self.session.current_user
      self:write({ redirect_to = "/" })
    end
  end,
  GET = function(self)
    return { render = true }
  end,
  POST = function(self)
    self.session.current_user =
      try_to_login(self.params.username, self.params.password)

    return { redirect_to = "/" }
  end
}))
```

```moon
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
```

## How do I work with forms?

## How do I restart a running server, or reload the code?

## How do I disable the stack trace on the error page?

## What versions of Lua are supported?

## How do I handle multiple domains and subdomains?

## How can I read the entire body of the request?
