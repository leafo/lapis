title: Utilities
--
# Utilities

## Functions

Utility functions are found in:

```lua
local util = require("lapis.util")
```

```moon
util = require "lapis.util"
```

### `unescape(str)`

URL unescapes string

### `escape(str)`

URL escapes string

### `escape_pattern(str)`

Escapes string for use in Lua pattern

### `parse_query_string(str)`

Parses query string into a table

### `encode_query_string(tbl)`

Converts a key,value table into a query string

### `underscore(str)`

Converst CamelCase to camel_case.

### `slugify(str)`

Converts a string to a slug suitable for a URL. Removes all whitespace and
symbols and replaces them with `-`.

### `uniquify(tbl)`

Iterates over array table `tbl` appending all unique values into a new array
table, then returns the new one.

###  `trim(str)

Trims the whitespace off of both sides of a string.

### `trim_all(tbl)`

Trims the whitespace off of all values in a table. Uses `pairs` to traverse
every key in the table.

The table is modified in place.

### `trim_filter(tbl, [{keys ...}], [empty_val=nil])`

Trims the whitespace off of all values in a table. The entry is removed from
the table if the result is an empty string.

If an array table `keys` is supplied then any other keys not in that list are
removed (with `nil`, not the `empty_val`)

If `empty_val` is provided then the whitespace only values are replaced with
that value instead of `nil`

The table is modified in place.

```lua
local db = require("lapis.db")
local trim_filter = require("lapis.util").trim_filter

unknown_input = {
  username = "     hello    ",
  level = "admin",
  description = " "
}

trim_filter(unknown_input, {"username", "description"}, db.NULL)

-- unknown input is now:
-- {
--   username = "hello",
--   description = db.NULL
-- }

```

```moon
db = require "lapis.db"
import trim_filter from require "lapis.util"

unknown_input = {
  username: "  hello  "
  level: "admin"
  description: " "
}

trim_filter unknown_input, {"username", "description"}, db.NULL

-- unknown input is now:
-- {
--   username: "hello"
--   description: db.NULL
-- }
```

### `to_json(obj)`

Converts `obj` to JSON. Will strip recursion and things that can not be encoded.

###  `from_json(str)`

Converts JSON to table, a direct wrapper around Lua CJSON's `decode`.

### Encoding Methods

Encoding functions are found in:

```lua
local encoding = require("lapis.util.encoding")
```

```moon
encoding = require "lapis.util.encoding"
```

### `encode_base64(str)`

Base64 encodes a string.

### `decode_base64(str)`

Base64 decodes a string.

### `hmac_sha1(secret, str)`

Calculates the hmac-sha1 digest of `str` using `secret`. Returns a binary
string.

### `encode_with_secret(object, secret=config.secret)`

Encodes a Lua object and generates a signature for it. Returns a single string
that contains the encoded object and signature.

### `decode_with_secret(msg_and_sig, secret=config.secret)`

Decodes a string created by `encode_with_secret`. The decoded object is only
returned if the signature is correct. Otherwise returns `nil` and an error
message. The secret must match what was used with `encode_with_secret`.

### `autoload(prefix, tbl={})`

Makes it so accessing an unset value in `tbl` will run a `require` to search
for the value. Useful for autoloading components split across many files.
Overwrites `__index` metamethod. The result of the require is stored in the
table.


```lua
local models = autoload("models")

models.HelloWorld --> will require "models.hello_world"
models.foo_bar --> will require "models.foo_bar"
```

```moon
models = autoload("models")

models.HelloWorld --> will require "models.hello_world"
models.foo_bar --> will require "models.foo_bar"
```

## CSRF Protection

CSRF protection provides a way to prevent fraudulent requests that originate
from other sites that are not your application. The common approach is to
generate a special token when the user lands on your page, then resubmit that
token on a subsequent POST request.

In Lapis the token is a cryptographically signed message that the server can
verify the authenticity of.

Before using any of the cryptographic functions it's important to set your
application's secret. This is a string that only the application knows about.
If your application is open source it's worthwhile to not commit this secret.
The secret is set in [your configuration](#configuration-and-environments) like so:

```lua
local config = require("lapis.config")

config("development", {
  secret = "this is my secret string 123456"
})

```

```moon
config = require "lapis.config"

config "development", ->
  secret "this is my secret string 123456"
```

Now that you have the secret configured, we might create a CSRF protected form
like so:


```lua
local lapis = require("lapis")
local csrf = require("lapis.csrf")

local capture_errors = require("lapis.application").capture_errors

local app = lapis.Application()

app:get("form", "/form", function(self)
  local csrf_token = csrf.generate_token(self)
  self:html(function()
    form({ method = "POST", action = self:url_for("form") }, function()
      input({ type = "hidden", name = "csrf_token", value = csrf_token })
      input({ type = "submit" })
    end)
  end)
end)

app:post("form", "/form", capture_errors(function(self)
  csrf.assert_token(self)
  "The form is valid!"
end))
```

```moon
csrf = require "lapis.csrf"

class extends lapis.Application
  [form: "/form"]: respond_to {
    GET: =>
      csrf_token = csrf.generate_token @
      @html =>
        form method: "POST", action: @url_for("form"), ->
          input type: "hidden", name: "csrf_token", value: csrf_token
          input type: "submit"

    POST: capture_errors =>
      csrf.assert_token @
      "The form is valid!"
  }
```

> If you're using CSRF protection in a lot of actions then it might be helpful
> to create a before filter that generates the token automatically.

The following functions are part of the CSRF module:

```lua
local csrf = require("lapis.csrf")
```

```moon
csrf = require "lapis.csrf"
```

###  `generate_token(req, key=nil, expires=os.time! + 28800)`

Generates a new CSRF token using the session secret. `key` is an optional piece
of data you can associate with the request. The token will expire in 8 hours by
default.

###  `validate_token(req, key)`

Valides the CSRF token located in `req.params.csrf_token`. If the token has a
key it will be validated against `key`. Returns `true` if it's valid, or `nil`
and an error message if it's invalid.

###  `assert_token(...)`

First calls `validate_token` with same arguments, then calls `assert_error` if
validation fails.


## Making HTTP Requests

Lapis comes with a built-in module for making asynchronous HTTP requests. The
way it works is by using the Nginx `proxy_pass` directive on an internal
action. Because of this, before you can make any requests you need to modify
your Nginx configuration.

Add the following to your server block:

```nginx
location /proxy {
    internal;
    rewrite_by_lua "
      local req = ngx.req

      for k,v in pairs(req.get_headers()) do
        if k ~= 'content-length' then
          req.clear_header(k)
        end
      end

      if ngx.ctx.headers then
        for k,v in pairs(ngx.ctx.headers) do
          req.set_header(k, v)
        end
      end
    ";

    resolver 8.8.8.8;
    proxy_http_version 1.1;
    proxy_pass $_url;
}
```

> This code ensures that the correct headers are set for the new request. The
> `$_url` variable is used to used to store the target URL. It must be defined
> as `$_url=""` in your default location.

Now we can use the `lapis.nginx.http` module. There are two methods. `request`
and `simple`. `request` implements the Lua Socket HTTP request API (complete
with LTN12).

`simple` is a simplified API with no LTN12:

```lua
local http = require("lapis.nginx.http")

local app = lapis.Application()

app:get("/", function(self)
  -- a simple GET request
  local body, status_code, headers = http.simple("http://leafo.net")

  -- a post request, data table is form encoded and content-type is set to
  -- application/x-www-form-urlencoded
  http.simple("http://leafo.net/", {
    name: "leafo"
  })

  -- manual invocation of the above request
  http.simple({
    url = "http://leafo.net",
    method = "POST",
    headers = {
      "content-type" = "application/x-www-form-urlencoded"
    },
    body: {
      name = "leafo"
    }
  })
end)
```


```moon
http = require "lapis.nginx.http"

class extends lapis.Application
  "/": =>
    -- a simple GET request
    body, status_code, headers = http.simple "http://leafo.net"

    -- a post request, data table is form encoded and content-type is set to
    -- application/x-www-form-urlencoded
    http.simple "http://leafo.net/", {
      name: "leafo"
    }

    -- manual invocation of the above request
    http.simple {
      url: "http://leafo.net"
      method: "POST"
      headers: {
        "content-type": "application/x-www-form-urlencoded"
      }
      body: {
        name: "leafo"
      }
    }
```

### `simple(req, body)`

Performs an HTTP request using the internal `/proxy` location.

Returns 3 values, the string result of the request, http status code, and a
table of headers.

If there is only one argument and it is a string then that argument is treated
as a URL for a GET request.

If there is a second argument it is set as the body of a POST request. If
the body is a table it is encoded with `encode_query_string` and the
`Content-type` header is set to `application/x-www-form-urlencoded`

If the first argument is a table then it is used to manually set request
parameters. It takes the following keys:

 * `url` -- the URL to request
 * `method` -- `"GET"`, `"POST"`, `"PUT"`, etc...
 * `body` -- string or table which is encoded
 * `headers` -- a table of request headers to set


### `request(url_or_table, body)`

Implements a subset of [Lua Socket's
`http.request`](http://w3.impa.br/~diego/software/luasocket/http.html#request).

Does not support `proxy`, `create`, `step`, or `redirect`.

## Caching

Lapis comes with a simple memory cache for caching the entire result of an
action keyed on the parameters it receives. This is useful for speeding up the
rendering of rarely changing pages because all database calls and HTML methods
can be skipped.

The Lapis cache uses the [shared dictionary
API](http://wiki.nginx.org/HttpLuaModule#lua_shared_dict) from HttpLuaModule.
The first thing you'll need to do is create a shared dictionary in your Nginx
configuration.

Add the following to your `http` block to create a 15mb cache:

```nginx
lua_shared_dict page_cache 15m;
```

Now we are ready to start using the caching module, `lapis.cache`.

### `cached(fn_or_tbl)`

Wraps an action to use the cache.

```lua
local lapis = require("lapis")
local cached = require("lapis.cache").cached

local app = lapis.Application()

app:match("my_page", "/hello/world", cached(function(self)
  return "hello world!"
end))
```

```moon
import cached from require "lapis.cache"

class extends lapis.Application
  [my_page: "/hello/world"]: cached =>
    "hello world!"
```

The first request to `/hello/world` will run the action and store the result in
the cache, all subsequent requests will skip the action and return the text
stored in the cache.

The cache will remember not only the raw text output, but also the content
type and status code.

The cache key also takes into account any GET parameters, so a request to
`/hello/world?one=two` is stored in a separate cache slot. Multiple parameters
are sorted so they can come in any order and still match the same cache key.

When the cache is hit, a special response header is set to 1,
`x-memory-cache-hit`. This is useful for debugging your application to make
sure the cache is working.

Instead of passing a function as the action of the cache you can also pass in a
table. When passing in a table the function must be the first numerically
indexed item in the table.

The table supports the following options:

* `dict_name` -- override the name of the shared dictionary used (defaults to `"page_cache"`)
* `exptime` -- how long in seconds the cache should stay alive, 0 is forever (defaults to `0`)
* `cache_key` -- set a custom function for generating the cache key (default is described above)
* `when` -- a function that should return truthy a value if the page should be cached. Receives the request object as first argument (defaults to `nil`)

For example, you could implement microcaching, where the page is cached for a
short period of time, like so:

```lua
local lapis = require("lapis")
local cached = require("lapis.cache").cached

local app = lapis.Application()

app:match("/microcached", cached({
  exptime = 1,
  function(self)
    return "hello world!"
  end
}))

```

```moon
import cached from require "lapis.cache"

class extends lapis.Application
  "/microcached": cached {
    exptime: 1
    => "hello world!"
  }
```

### `delete(key, [dict_name="page_cache"])`

Deletes an entry from the cache. Key can either be a plain string, or a tuple
of `{path, params}` that will be encoded as the key.


```lua
local cache = require("lapis.cache")
cache.delete({ "/hello", { thing = "world" } })
```

```moon
cache = require "lapis.cache"
cache.delete { "/hello", { thing: "world" } }
```

### `delete_all([dict_name="page_cache"])`

Deletes all entires from the cache.

### `delete_path(path, [dict_name="page_cache"])`

Deletes all entries for a specific path.

```lua
local cache = require("lapis.cache")
cache.delete_path("/hello")
```

```moon
cache = require "lapis.cache"
cache.delete_path "/hello"
```

## File Uploads

File uploads can be handled with a multipart form and accessing the file from
the <span class="for_moon">`@params`</span><span
class="for_lua">`self.params`</span> of the request.

For example, let's create the following form:

```moon
import Widget from require "lapis.html"

class MyForm extends Widget
  content: =>
    form {
      action: "/my_action"
      method: "POST"
      enctype: "multipart/form-data"
    }, ->
      input type: "file", name: "uploaded_file"
      input type: "submit"
```

When the form is submitted, the file is stored as a table with `filename` and
`content` properties in <span class="for_moon">`@params`</span><span
class="for_lua">`self.params`</span> under the name of the form input:

```lua
locl app = lapis.Application()

app:post("/my_action", function(self)
  local file = @params.uploaded_file
  if file then
    return "Uploaded: " .. file.filename .. ", " .. #file.content .. "bytes"
  end
end)
```

```moon
class extends lapis.Application
  "/my_action": =>
    if file = @params.uploaded_file
      "Uploaded #{file.filename}, #{#file.content}bytes"

```

A validation exists for ensuring that a param is an uploaded file, it's called
`is_file`:

```lua
local app = lapis.Application()

app:post("/my_action", function(self)
  assert_valid(self.params, {
    { "uploaded_file", is_file: true }
  })

  -- file is ready to be used
end)
```

```moon
class extends lapis.Application
  "/my_action": capture_errors =>
    assert_valid @params, {
      { "uploaded_file", is_file: true }
    }

    -- file is ready to be used...
```

An uploaded file is loaded entirely into memory, so you should be careful about
the memory requirements of your application. Nginx limits the size of uploads
through the
[`client_max_body_size`](http://wiki.nginx.org/HttpCoreModule#client_max_body_size)
directive. It's only 1 megabyte by default, so if you plan to allow uploads
greater than that you should set a new value in your Nginx configuration.

## Application Helpers

The following functions are part of the `lapis.application` module:

```lua
local app_helpers = require("lapis.application")
```

```moon
application = require "lapis.application"
```

### `fn = respond_to(verbs_to_fn={})`

`verbs_to_fn` is a table of functions that maps a HTTP verb to a corresponding
function. Returns a new function that dispatches to the correct function in the
table based on the verb of the request. See
[Handling HTTP verbs](#lapis-applications-handling-http-verbs)

If an action for `HEAD` does not exist Lapis inserts the following function to
render nothing:

```lua
function() return { layout = false } end
```

```moon
-> { layout: false }
```

If the request is a verb that is not handled then the Lua `error` function
is called and a 500 page is generated.

A special `before` key can be set to a function that should run before any
other action. If <span class="for_moon">`@write`</span><span
class="for_lua">`self.write`</span> is called inside the before function then
the regular handler will not be called.

### `safe_fn = capture_errors(fn_or_tbl)`

Wraps a function to catch errors sent by `yield_error` or `assert_error`. See
[Exception Handling][0] for more information.

If the first argument is a function then that function is called on request and
the following default error handler is used:

```lua
function() return { render = true } end
```

```moon
-> { render: true }
```

If a table is the first argument then the `1`st element of the table is used as
the action and value of `on_error` is used as the error handler.

When an error is yielded then the <span class="for_moon">`@errors`</span><span
class="for_lua">`self.errors`</span> variable is set on the current request and
the error handler is called.

### `safe_fn = capture_errors_json(fn)`

A wrapper for `capture_errors` that passes in the following error handler:

```lua
function(self) return { json = { errors = self.errors } } end
```

```moon
=> { json: { errors: @errors } }
```

### `yield_error(error_message)`

Yields a single error message to be captured by `capture_errors`

### `obj, msg, ... = assert_error(obj, msg, ...)`

Works like Lua's `assert` but instead of triggering a Lua error it triggers an
error to be captured by `capture_errors`


### `wrapped_fn = json_params(fn)`

Return a new function that will parse the body of the request as JSON and
inject it into `@params` if the `content-type` is set to `application/json`.

```lua
local json_params = requrie("lapis.application").json_params

app:match("/json", json_params(function(self)
  return self.params.value
end)
```

```moon
import json_params from require "lapis.application"

class JsonApp extends lapis.Application
  "/json": json_params =>
    @params.value
```

```bash
$ curl \
  -H "Content-type: application/json" \
  -d '{"value": "hello"}' \
  'https://localhost:8080/json'
```

The unmerged params can also be accessed from <span
class="for_moon">`@json`</span><span class="for_lua">`self.json`</span>. If
there was an error parsing the JSON then <span
class="for_moon">`@json`</span><span class="for_lua">`self.json`</span> will be
`nil` and the request will continue.

