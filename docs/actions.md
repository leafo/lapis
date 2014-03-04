
## Request Object

Every action is passed the *request object* as its first argument when called.
Because of the convention to call the first argument `self` we refer to the
request object as `self` when in the context of an action.

The request object has the following parameters:

* <span class="for_moon">`@params`</span><span class="for_lua">`self.params`</span> -- a table containing all the get, post, and url parameters together
* <span class="for_moon">`@req`</span><span class="for_lua">`self.req`</span> -- raw request table (generated from `ngx` state)
* <span class="for_moon">`@req`</span><span class="for_lua">`self.req`</span> -- raw request table (generated from `ngx` state)
* <span class="for_moon">`@res`</span><span class="for_lua">`self.res`</span> -- raw response table (used to update `ngx` state)
* <span class="for_moon">`@app`</span><span class="for_lua">`self.app`</span> -- the instance of the application
* <span class="for_moon">`@cookies`</span><span class="for_lua">`self.cookies`</span> -- the table of cookies, can be assigned to set new cookies. Only supports strings as values
* <span class="for_moon">`@session`</span><span class="for_lua">`self.session`</span> -- signed session table. Can store values of any type that can be JSON encoded. Is backed by cookies
* <span class="for_moon">`@options`</span><span class="for_lua">`self.options`</span> -- set of options that controls how the request is rendered to Nginx
* <span class="for_moon">`@buffer`</span><span class="for_lua">`self.buffer`</span> -- the output buffer
* <span class="for_moon">`@route_name`</span><span class="for_lua">`self.route_name`</span> -- the name of the route that matched the request if it has one


### @req

The raw request table <span class="for_lua">`@req`</span><span class="for_lua">`self.req`</span> wraps some of the data provided from `ngx`. Here is a list of the available properties.

* <span class="for_moon">`@req.headers`</span><span class="for_lua">`self.headers`</span> -- Request headers table
* <span class="for_moon">`@req.parsed_url`</span><span class="for_lua">`self.parsed_url`</span> -- Request parsed url. A table containing `scheme`, `path`, `host`, `port`, and `query` properties.
* <span class="for_moon">`@req.params_post`</span><span class="for_lua">`self.params_post`</span> -- Request POST parameters table
* <span class="for_moon">`@req.params_get`</span><span class="for_lua">`self.params_get`</span> -- Request GET parameters table

### Request Options

Whenever a table is written, the key/value pairs (for keys that are strings)
are copied into <span class="for_moon">`@options`</span><span
class="for_lua">`self.options`</span>. For example, in the following action the
`render` and `status` properties are copied. The options table is used at
the end of the action lifecycle to create the appropriate response.

```lua
app:match("/", function(self)
  return { render = "error", status = 404}
end)
```

```moon
"/": => render: "error", status: 404
```

Here is the list of options that can be written

* `status` -- sets HTTP status code (eg. 200, 404, 500, ...)
* `render` -- causes a view to be rendered with the request. If the value is
  `true` then the name of the route is used as the view name. Otherwise the value must be a string or a view class.
* `content_type` -- sets the `Content-type` header
* `json` -- causes the request to return the JSON encoded value of the property. The content type is set to `application/json` as well.
* `layout` -- changes the layout from the default defined by the application
* `redirect_to` -- sets status to 302 and sets `Location` header to value. Supports both relative and absolute URLs. (Combine with `status` to perform 301 redirect)


When rendering JSON make sure to use the `json` render option. It will
automatically set the correct content type and disable the layout:

```lua
app:match("/hello", function(self)
  return { json = { hello = "world" } }
end)
```

```moon
class extends lapis.Application
  "/hello": =>
    json: { hello: "world!" }
```

### Cookies

The <span class="for_moon">`@cookies`</span><span
class="for_lua">`self.cookies`</span> table in the request lets you read and
write cookies. If you try to iterate over the table to print the cookies you
might notice it's empty:


```lua
app:match("/my-cookies", function(self)
  for k,v in pairs(self.cookies) do
    print(k, v)
  end
end)
```

```moon
"/my-cookies": =>
  for k,v in pairs(@cookies)
    print k,v
```

The existing cookies are stored in the `__index` of the metatable. This is done
so we can when tell what cookies have been assigned to during the action
because they will be directly in the <span
class="for_moon">`@cookies`</span><span class="for_lua">`self.cookies`</span>
table.

Thus, to set a cookie we just need to assign into the <span
class="for_moon">`@cookies`</span><span class="for_lua">`self.cookies`</span>
table:

```lua
app:match("/sets-cookie", function(self)
  self.foo = "bar"
end)
```

```moon
"/sets-cookie": =>
  @cookies.foo = "bar"
```

### Session

The <span class="for_moon">`@session`</span><span
class="for_lua">`self.session`</span> is a more advanced way to persist data
over requests. The content of the session is serialized to JSON and stored in
store in a specially named cookie. The serialized cookie is also signed with
you application secret so it can't be tampered with. Because it's serialized
with JSON you can store nested tables and other primitive values.

The session can be set and read the same way as cookies:

```lua
app.match("/", function(self)
  if not self.session.current_user then
    self.session.current_user = "Adam"
  end
end)
```

```moon
"/": =>
  unless @session.current_user
    @session.current_user = "Adam"
```

By default the session is stored in a cookie called `lapis_session`. You can
overwrite the name of the session using the `session_name` [configuration
variable](#configuration-and-environments). Sessions are signed with your
application secret, which is stored in the configuration value `secret`. It is
highly recommended to change this from the default.

```lua
-- config.moon
local config = require("lapis.config").config

config("development", {
  session_name = "my_app_session",
  secret = "this is my secret string 123456"
})
```

```moon
-- config.moon
import config from require "lapis.config"

config "development", ->
  session_name "my_app_session"
  secret "this is my secret string 123456"
```

### Methods

####  `write(things...)`

Writes all of the arguments. A different actions is done depending on the type
of each argument.

* `string` -- String is appended to output buffer
* `function` (or callable table) -- Function is called with the output buffer, result is recursively passed to `write`
* `table` -- key/value pairs are assigned into <span class="for_moon">`@options`</span><span class="for_lua">`self.options`</span>, all other values are recursively passed to `write`


#### `url_for(name_or_obj, params)`

Generates a URL for `name_or_obj`.

If `name_or_obj` is a string, then the route of that name is looked up and
filled using the values in params.

For example:

```lua
app:match("user_data", "/data/:user_id/:data_field", function()
  return "hi"
end)

app:match("/", function(self)
  -- returns: /data/123/height
  self.url_for("user_data", { user_id = 123, data_field = "height"})
end)
```

```moon
[user_data: "/data/:user_id/:data_field"]: =>

"/": =>
  -- returns: /data/123/height
  @url_for "user_data", user_id: 123, data_field: "height"
```

If `name_or_obj` is a table, then the `url_params` method is called on the
object. The arguments passed to `url_params` are the request, followed by all
the remaining arguments passed to `url_for`. The result of `url_params` is used
to call `url_for` again.

The values of params are inserted literally into the URL if they are strings.
If the value is a table then the `url_key` method is called and the result is
used as the URL value.

For example, consider a `Users` model and generating a URL for it:


```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  url_key = function(self, route_name)
    return self.id
  end
})
```


```moon
class Users extends Model
  url_key: (route_name) => @id
```

#### `build_url(path, [options])`

Builds an absolute URL for the path. The current request's URI is used to build
the URL.

For example, if we are running our server on `localhost:8080`:


```lua
self:build_url() --> http://localhost:8080
self:build_url("hello") --> http://localhost:8080/hello

self:build_url("world", { host = "leafo.net", port = 2000 }) --> http://leafo.net:2000/world
```

```moon
@build_url! --> http://localhost:8080
@build_url "hello" --> http://localhost:8080/hello

@build_url "world", host: "leafo.net", port: 2000 --> http://leafo.net:2000/world
```
