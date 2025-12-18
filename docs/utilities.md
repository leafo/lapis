{
  title: "Utilities"
}
# Utilities

## Functions <span stat-keyword="util"></span>

Utility functions are found in:

$dual_code{[[
util = require "lapis.util"
]]}

### `unescape(str)`

URL unescapes string, returning the resulting string.

$dual_code{
lua = [[
  local util = require "lapis.util"
  local original_string = "Hello%2C%20World%21"
  local unescaped_string = util.unescape(original_string)

  print(unescaped_string)  -- Output: "Hello, World!"
]],
moon = [[
  util = require "lapis.util"
  original_string = "Hello%2C%20World%21"
  unescaped_string = util.unescape original_string

  print unescaped_string  -- Output: "Hello, World!"
]]
}

### `escape(str)`

URL escapes string, returning the resulting string.

$dual_code{
lua = [[
  local util = require "lapis.util"
  local original_string = "Hello, World!"
  local escaped_string = util.escape(original_string)

  print(escaped_string)  -- Output: "Hello%2C%20World%21"
]],
moon = [[
  util = require "lapis.util"
  original_string = "Hello, World!"
  escaped_string = util.escape original_string

  print escaped_string  -- Output: "Hello%2C%20World%21"
]]
}

### `escape_pattern(str)`

Escapes string for use in Lua pattern. This function is useful for instances
where you want to use a string as a pattern in Lua's string matching functions,
but the string may contain special characters that have special meanings in Lua
patterns.

$dual_code{
lua = [[
  local util = require("lapis.util")
  local pattern = util.escape_pattern("[special]")
  print(pattern)  -- Output: "%[special%]"
]],
moon = [[
  util = require "lapis.util"
  pattern = util.escape_pattern "[special]"
  print pattern  -- Output: "%[special%]"
]]
}

### `parse_query_string(str)`

Parses a query string into a table. Note that if query keys do not include a
value, their value will be set to `true` in the table. Each parsed tuple is
inserted into the table in two ways: first as a `[key] = value`, which overwrites any
existing keys, and secondly, it is appended to the end of the array portion of the table
as `{key, value}`.

> The query string being parsed should not start with a '?'. The function only
> processes the key-value pairs and does not handle the '?' character typically
> used at the start of query strings in URLs.

$dual_code{
lua = [[
  local util = require("lapis.util")
  local query_table = util.parse_query_string("key1=value1&key2&key1=value2")
  print(query_table["key1"])  -- "value2"
  print(query_table["key2"])  -- true

  -- numeric indicies showing duplicates
  print(unpack(query_table[1]))  -- "key1", "value1"
  print(unpack(query_table[2]))  -- "key2", true
  print(unpack(query_table[3]))  -- "key1", "value2"
]],
moon = [[
  util = require "lapis.util"
  query_table = util.parse_query_string "key1=value1&key2&key1=value2"
  print query_table["key1"]  -- "value2"
  print query_table["key2"]  -- true

  -- numeric indicies showing duplicates
  print unpack query_table[1]  -- "key1", "value1"
  print unpack query_table[2]  -- "key2"
  print unpack query_table[1]  -- "key1", "value2"
]]
}

### `encode_query_string(tbl)`

Converts a key-value table into a query string. For ordered query strings, the
numeric indices of the table can also be a table in the form `{key, value}`.
The two formats can be mixed into the same table and all parameters will be encoded.

> The output of `parse_query_string`, if passed directly into
> `encode_query_string`, will cause duplicates due to the parsing structure. To
> re-encode, either strip the hash table parts or strip the numeric indices.

$dual_code{
lua = [[
  local util = require("lapis.util")
  local example1 = util.encode_query_string({key1 = "value1", key2 = true})
  print(example1)  -- Output: "key1=value1&key2"

  -- example with numeric indices pairs that guarantees output order
  local example2 = util.encode_query_string({{key1 = "value1"}, {key2 = true}})
  print(example2)  -- Output: "key1=value1&key2"
]],
moon = [[
  util = require "lapis.util"
  example1 = util.encode_query_string {key1: "value1", key2: true}
  print example1  -- Output: "key1=value1&key2"

  -- example with numeric indices pairs that guarantees output order
  example2 = util.encode_query_string {{"key1", "value1"}, {"key2", true}}
  print example2  -- Output: "key1=value1&key2"
]]
}


### `underscore(str)`

Convert CamelCase to camel_case. This is used in various parts of Lapis, such
as handling the automatic translation of names like converting a class name to
a database table name.

$dual_code{
lua = [[
  local util = require("lapis.util")
  local underscored = util.underscore("CamelCase")
  print(underscored)  -- Output: "camel_case"
]],
moon = [[
  util = require "lapis.util"
  underscored = util.underscore "CamelCase"
  print underscored  -- Output: "camel_case"
]]
}

### `slugify(str)`

Converts a string to a slug suitable for a URL. Removes all whitespace and
symbols and replaces them with `-`.

> It might be worthwhile to check if the output is an empty string, to ensure
> that a slug could be generated from the input string. For example, a string
> composed entirely of symbols will be converted into an empty string.

$dual_code{
lua = [[
  local util = require("lapis.util")
  local slug = util.slugify("Hello World!")
  print(slug)  -- Output: "hello-world"

  local slug2 = util.slugify("!!!@@@###$$$")
  print(slug2)  -- Output: ""
]],
moon = [[
  util = require "lapis.util"
  slug = util.slugify "Hello World!"
  print slug  -- Output: "hello-world"

  slug2 = util.slugify "!!!@@@###$$$"
  print slug2  -- Output: ""
]]
}

### `uniquify(tbl)`

Iterates over the array table `tbl`, appending all unique values into a new
array table, and then returns this new table. The original table is not
modified; a new table is always returned.

$dual_code{
lua = [[
  local util = require("lapis.util")
  local unique_table = util.uniquify({1, 2, 2, 3, 3, 3})
  print(unpack(unique_table))  -- Output: 1, 2, 3
]],
moon = [[
  util = require "lapis.util"
  unique_table = util.uniquify {1, 2, 2, 3, 3, 3}
  print unpack unique_table  -- Output: 1, 2, 3
]]
}

### `trim(str)`

Trims the whitespace from both sides of a string. Note that this function is
only aware of ASCII whitespace characters, such as space, newline, tab, etc.
For full Unicode/UTF8 support, see the `lapis.util.utf8` module.

$dual_code{
lua = [[
  local util = require("lapis.util")
  local trimmed = util.trim("   Hello World!   ")
  print(trimmed)  -- Output: "Hello World!"
]],
moon = [[
  util = require "lapis.util"
  trimmed = util.trim "   Hello World!   "
  print trimmed  -- Output: "Hello World!"
]]
}

### `trim_all(tbl)`

Trims the whitespace from all values in a table. It uses `pairs` to traverse
every key in the table. Trimming is performed with the `trim` function provided in
the `lapis.util` module.

The table is modified in place.

$dual_code{
lua = [[
  local util = require("lapis.util")
  local trimmed_table = {key1 = "   value1   ", key2 = "   value2   "}
  util.trim_all(trimmed_table)
  for k, v in pairs(trimmed_table) do print(k, v) end  -- Output: key1 value1, key2 value2
]],
moon = [[
  util = require "lapis.util"
  trimmed_table = {key1: "   value1   ", key2: "   value2   "}
  util.trim_all trimmed_table
  for k, v in pairs(trimmed_table) do print(k, v) end  -- Output: key1 value1, key2 value2
]]
}

### `trim_filter(tbl, [{keys ...}], [empty_val=nil])`

Trims the whitespace off of all values in a table. The entry is removed from
the table if the trimmed value is an empty string.

If an array table `keys` is supplied then any other keys not in that list are
removed (with `nil`, not the `empty_val`)

If `empty_val` is provided then the whitespace only values are replaced with
that value instead of `nil`

The table is modified in place.

$dual_code{
lua = [[
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
]],
moon = [[
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
]]
}

### `to_json(obj)`

Converts `obj` to JSON. This process removes recursion and elements that cannot
be encoded, thus preventing infinite recursion. The following types are
stripped: userdata, function, thread.

$dual_code{
lua = [[
  local util = require "lapis.util"
  local example1 = util.to_json({1,2,3})
  print(example1)  -- Output: "[1,2,3]"

  local example2 = util.to_json({hello = "world"})
  print(example2)  -- Output: '{"hello":"world"}'
]],
moon = [[
  util = require "lapis.util"
  example1 = util.to_json {1,2,3}
  print example1  -- Output: "[1,2,3]"

  example2 = util.to_json {hello: "world"}
  print example2  -- Output: '{"hello":"world"}'
]]
}

###  `from_json(str)`

Converts JSON to table, a direct wrapper around Lua CJSON's `decode`.

### `time_ago_in_words(date, [parts=1], [suffix="ago"])`

Returns a string in the format "1 day ago".

`parts` allows you to add more words. With `parts=2`, the string
returned would be in the format `1 day, 4 hours ago`.

### `autoload(prefix, tbl={})`

Modifies `tbl` such that accessing an unset value in `tbl` will run a `require`
to search for the value. This is useful for autoloading components split across
many files. It overwrites the `__index` metamethod. The result of the require
is cached in the table, so the loading process only happens once. Returns the
`tbl` value.

> By default, a new empty table is created for the 'tbl' argument, so it's not
> necessary to provide one if you intend to create a new autoloading table.

The following is the list of search patterns tried in order when requesting an
unloaded field:

1. `require("#{prefix}.#{field}")`
2. `require("#{prefix}.#{util.underscore(field)}")`

If a module is not able to be located, an error is thrown.

$dual_code{
lua = [[
local util = require("lapis.util")
local models = util.autoload("models")

local _ = models.HelloWorld --> will require "models.hello_world"
local _ = models.foo_bar --> will require "models.foo_bar"
]],
moon = [[
util = require("lapis.util")
models = autoload("models")

models.HelloWorld --> will require "models.hello_world"
models.foo_bar --> will require "models.foo_bar"
]]
}


## Encoding Methods

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


## CSRF Protection

CSRF protection provides a way to prevent unauthorized requests that originate
from other sites that are not your application. The common approach is to
generate a special token that is placed on pages that make need to make calls
with HTTP methods that are not *safe* (POST, PUT, DELETE, etc.). This token
must be sent back to the server on the requests to verify the request came from
a page generated by your application.

The default CSRF implementation generates a random string on the server and
stores it in the cookie. (The cookie's name is your session name followed by
`_token`.) The CSRF token is a cryptographically signed string that contains
the random string. You can optionally attach data to the CSRF token to control
how it can expire.

Before using any of the cryptographic functions it's important to set your
application's secret. This is a string that only the application knows about.
If your application is open source it's worthwhile to not commit this secret.
The secret is set in [your configuration](#configuration-and-environments) like so:

$dual_code{
lua = [[
local config = require("lapis.config")

config("development", {
  secret = "this is my secret string 123456"
})
]],
moon = [[
config = require "lapis.config"

config "development", ->
  secret "this is my secret string 123456"
]]
}

Now that you have the secret configured, we might create a CSRF protected form
like so:


$dual_code{
lua = [[
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
  return "The form is valid!"
end))
]],
moon = [[
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
]]
}

> If you're using CSRF protection in a lot of actions then it might be helpful
> to create a before filter that generates the token automatically.

The following functions are part of the CSRF module:

$dual_code{[[
csrf = require "lapis.csrf"
]]}

### `csrf.generate_token(req, data=nil)`

Generates a token for the current session. If a random string has not been set
in the cookie yet, then it will be generated. You can optionally pass in data
to have it encoded into the token. You can then use the `callback` parameter of
`validate_token` to verify data's value.

The random string is stored in a cookie named as your session name with
`_token` appended to the end.

### `csrf.validate_token(req, callback=nil)`

Validates the CSRF token located in `req.params.csrf_token`. For any endpoints
you validation the token on you must pass the query or form parameter
`csrf_token` with the value of the token returned by `generate_token`.

If the validation fails then `nil` and an error message are returned. A
callback function can be provided as the second argument. It's a function that
will be called with the data payload stored in the token. You can specify the
data with the second argument of `generate_token`.

Here's an example of adding an expiration date using the token data:

$dual_code{
lua = [[
local lapis = require("lapis")
local csrf = require("lapis.csrf")

local capture_errors = require("lapis.application").capture_errors

local app = lapis.Application()

app:get("form", "/form", function(self)
  local csrf_token = csrf.generate_token(self, {
    -- expire in 4 hours
    expires = os.time() + 60*60*4
  })
  -- render a form using csrf_token...
end)

app:post("form", "/form", capture_errors(function(self)
  csrf.assert_token(self, function(data)
    if os.time() > (data.expires or 0) then
      return nil, "token is expired"
    end

    return true
  end)

  return "The request is valid!"
end))
]],
moon = [[
csrf = require "lapis.csrf"

class extends lapis.Application
  [form: "/form"]: respond_to {
    GET: =>
      csrf_token = csrf.generate_token @, {
        -- expire in 4 hours
        expires: os.time! + 60*60*4
      }
      -- render a form using csrf_token...

    POST: capture_errors =>
      csrf.assert_token @, (d) ->
        if os.time() > (d.expires or 0) then
          return nil, "token is expired"
        true

      "The form is valid!"
  }
]]
}

###  `csrf.assert_token(...)`

First calls `validate_token` with same arguments, then calls `assert_error` if
validation fails.

## Making HTTP Requests

The `lapis.http` module will attempt to select an HTTP client that works in the
current server/environment. All of these modules should implement LuaSocket's
`request` function interface. See: <https://lunarmodules.github.io/luasocket/http.html#request>

* When using Nginx: `lapis.nginx.http`
* When using Cqueues/lua-http: `http.compat.socket`
* Default: LuaSocket's `socket.http` (Note: `luasec` is required to perform HTTPS requests)

$dual_code{
lua = [[
  local http = require("lapis.http")
  local ltn12 = require("ltn12")

  -- a simple GET request
  local body, status_code, headers = http.request("http://leafo.net")

  -- a simple POST request
  local out = {}
  local _, status_code, headers = http.request({
    url = "http://leafo.net",
    method = "POST",
    headers = { ["Content-type"] = "application/x-www-form-urlencoded" },
    source = ltn12.source.string("param1=value1&param2=value2"),
    sink = ltn12.sink.table(out)
  })

  local body = table.concat(out)
]],
moon = [[
  http = require "lapis.http"
  ltn12 = require "ltn12"

  -- a simple GET request
  body, status_code, headers = http.request "http://leafo.net"


  out = {}
  _, status_code, headers = http.request {
    url: "http://leafo.net",
    method: "POST",
    headers: { ["Content-type"] = "application/x-www-form-urlencoded" }
    source: ltn12.source.string "param1=value1&param2=value2"
    sink ltn12.sink.table(out)
  }

  body = table.concat out
]]
}


For OpenResty, Lapis will use nginx's `proxy_pass` directive as an HTTP client.
In our tests, this has been the most reliable solution available that is fully
asynchronous and will not block your workers. Before you can make any requests,
you must modify your Nginx configuration to add a special `location` block that will facilitate the HTTP request.

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

> This code ensures that the correct headers are set for the subrequest that is
> created.

Additionally, in the nginx `location` that processes your Lapis requests, you
need to define the `$_url` variable, which will hold the request URL.

```nginx
location / {
  set $_url ""; # Add this line
  content_by_lua "require('lapis').serve('app')";
  # ...
}
```

Now we can use the `lapis.nginx.http` module. There are two methods. `request`
and `simple`. `request` implements the Lua Socket HTTP request API (complete
with LTN12).

`simple` is a simplified API with no LTN12:

$dual_code{
lua = [[
local http = require("lapis.http")

local app = lapis.Application()

app:get("/", function(self)
  -- a simple GET request
  local body, status_code, headers = http.request("http://leafo.net")
end)
]],
moon = [[
http = require "lapis.nginx.http"

class extends lapis.Application
  "/": =>
    -- a simple GET request
    body, status_code, headers = http.request "http://leafo.net"
]]
}


### `http.request(url_or_table, body)`

This is documentation for the Lapis Nginx-specific implementation of the
[LuaSocket request
function](https://lunarmodules.github.io/luasocket/http.html#request). Although
this function attempts to cover the most common calling cases, it is not a
perfect replacement.

When used in Nginx, this function is non-blocking. The function does not
support streaming responses, which means large request responses will be
buffered entirely into memory. The result cannot be read until the full request
completes. Also, it does not support `proxy`, `create`, `step`, or `redirect`
parameters of LuaSocket's request function.

The `/proxy` location described above must exist in the same server block that
is handling the original request for this function to work.

> If you are looking for a more flexible HTTP client that is specific to Nginx,
> look at <https://github.com/ledgetech/lua-resty-http>

**Parameters:**

- `url_or_table`: This can either be a string specifying the URL for a simple GET/POST request, or a table for more complex requests. If a table, the following keys can be used:
  - `url`: The URL to request.  (Required)
  - `method`: The HTTP method to use, for example: `"GET"`, `"POST"`, `"PUT"`, etc.
  - `source`: An `ltn12` source that generates the body of the request.
  - `headers`: A plain table of headers to include in the request.
  - `sink`: An `ltn12` sink that will receive the output of the request.
- `body`: This arugment is only used if `url_or_table` is provided as a string. Converts the request to a POST request and adds the `"Content-type: application/x-www-form-urlencoded"` header pair

**Returns:**

The function returns three values:

1. `body`: The string result of the request. If a `sink` is provided, then the body is returned as the number value `1`, and the body should be read from the sink.
2. `status`: The HTTP status code of the response, as a number.
3. `headers`: A table of headers from the response.

Every successful HTTP request increments the following performance metrics in the Nginx context:

- `http_count`: This metric counts the total number of HTTP requests.
- `http_time`: This metric measures the total time taken for HTTP requests. It is calculated as the difference between the current time and the start time of the request.

### `http.simple(req, body)`

> This function is now deprecated. We recommend using the `http.request`
> interface, which is compatible with multiple HTTP clients.

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


## Caching

> The caching functionality here is very rudimentary. If you are looking for
> more robust caching, look into the `proxy_cache` directive that is part of
> the Nginx HTTP proxy module:
> <https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache>

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

### `cache.cached(fn_or_tbl)`

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

### `cache.delete(key, [dict_name="page_cache"])`

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

### `cache.delete_all([dict_name="page_cache"])`

Deletes all entries from the cache.

### `cache.delete_path(path, [dict_name="page_cache"])`

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
local app = lapis.Application()

app:post("/my_action", function(self)
  local file = self.params.uploaded_file
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
    { "uploaded_file", is_file = true }
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

### `respond_to(verbs_to_fn={})`

`verbs_to_fn` is a table of functions that maps a HTTP verb to a corresponding
function. Returns a new function that dispatches to the correct function in the
table based on the verb of the request. See
[Handling HTTP verbs][1]

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

### `capture_errors(fn_or_tbl)`

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

### `capture_errors_json(fn)`

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


### `json_params(fn)`

Return a new function that will parse the body of the request as JSON and
inject it into $self_ref{"params"} if the `content-type` is set to
`application/json`. Suitable for wrapping an action handler to make it aware of
JSON encoded requests.

```lua
local json_params = require("lapis.application").json_params

app:match("/json", json_params(function(self)
  return self.params.value
end))
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

The unmerged parameters can also be accessed from $self_ref{"json"}. If there
was an error parsing the JSON then $self_ref{"json"} will be `nil` and the
request will continue without error.

## UTF8

This module includes a collection of LPeg patterns for working with UTF8 text.

$dual_code{[[
utf8 = requrie("lapis.util.utf8")
]]}

### `utf8.trim`

A pattern that will trim all invisible characters from either side of the
matched string. (Utilizes the `whitespace` pattern described below)

$dual_code{[[
utf8 = require "lapis.util.utf8"
original_string = "    Hello, World!    "
trimmed_string = utf8.trim\match(original_string)

print(trimmed_string)  -- Output: "Hello, World!"
]]}

### `utf8.printable_character`

A pattern that matches a single printable character. Note that printable
characters include whitepace, but don't include invalid unicode codepoints or
control characters.

### `utf8.whitespace`

An optimal pattern that matches any unicode codepoints that are classified as
whitespace.

### `utf8.string_length`

Calculates the length of a string, counting each printable character. It takes
a string as an argument and returns the number of printable characters in the
string. This is aware of multi-byte characters:

$dual_code{[[
utf8 = require "lapis.util.utf8"
multi_byte_string = "こんにちは世界"
string_length = utf8.string_length(multi_byte_string)

print(string_length)  -- Output: 7
]]}


[0]: exception_handling.html
[1]: actions.html#handling-http-verbs
