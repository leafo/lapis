title: Requests and Actions
--
# Requests and Actions

Every HTTP request that is handled by Lapis follows the same basic flow after
being handed off from Nginx. The first step is routing. A *route* is a pattern
that a URL must match. When you define a route you also include an *action*. An
action is a regular Lua/MoonScript function that will be called if the
associated route matches.

All actions are called with one argument, a [*request
object*](#request-object).

The return value of the action is used to render the output. A string return
value will be rendered to the browser directly. A table return value
will be used as the [*render options*](#render-options).

If there is no route that matches the request then the default route handler is
executed, read more in [*application callbacks*](#application-callbacks).

## Routes & URL Patterns

Route patterns use a special syntax to define dynamic parameters of the URL and
assign a name to them. The simplest routes have no parameters though:


```lua
local lapis = require("lapis")
local app = lapis.Application()

app:match("/", function(self) end)
app:match("/hello", function(self) end)
app:match("/users/all", function(self) end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  "/": =>
  "/hello": =>
  "/users/all": =>
```

These routes match the URLs verbatim. The leading `/` is required. The route
must match the entire path of the request. That means a request to
`/hello/world` will not match the route `/hello`.

You can specify a named parameter with a `:` followed immediately by the name.
The parameter will match all characters excluding `/`:


```lua
app:match("/page/:page", function(self)
  print(self.params.page)
end)

app:match("/post/:post_id/:post_name", function(self) end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  "/page/:page": => print @params.page
  "/post/:post_id/:post_name": =>
```

> In the example above we called `print` to debug. When running inside
> OpenResty, the output of `print` is sent to the Nginx notice log.

The captured values of the route parameters are saved in the `params` field of
the request object by their name. A named parameter must contain at least 1
character, and will fail to match otherwise.

There's one other capture type, a splat. A splat, or `*` will match at least 1
character all the way to the end of the path (including `/`). The splat is
stored in a `splat` fields in the `params` table of the request object.

```lua
app:match("/browse/*", function(self)
  print(self.params.splat)
end)
app:match("/user/:name/file/*", function(self) end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  "/browse/*": =>
    print @params.splat

  "/user/:name/file/*": =>
    print @params.name, @params.splat
```

It is currently not valid to put anything after the splat as the splat is
greedy and will capture all characters.

## Named Routes

It's useful to give names to your routes so links to other pages can be
generated just by knowing the name of the page instead of hard-coding the
structure of the URL.

<span class="for_moon">If the route of the action is a table with a single
pair, then the key of that table is the name and the value is the pattern.
MoonScript gives us convenient syntax for representing this:</span><span
class="for_lua">Every method on the application that defines a new route has a
second form that takes the name of the route as the first argument:</span>

```lua
local lapis = require("lapis")
local app = lapis.Application()

app:match("index", "/", function(self)
  return self:url_for("user_profile", { name = "leaf" })
end)

app:match("user_profile", "/", function(self)
  return "Hello " .. self.params.name .. ", go home: " .. self:url_for("index")
end)
```

```moon
lapis = require "lapis"

class extends lapis.Application
  [index: "/"]: =>
    @url_for "user_profile", name: "leaf"

  [user_profile: "/user/:name"]: =>
    "Hello #{@params.name}, go home: #{@url_for "index"}"
```

We can generate the paths to various actions using <span
class="for_moon">`@url_for`</span><span
class="for_lua">`self:url_for()`</span>. The first argument is the name of the
route, and the second optional argument is a table of values to fill a
parameterized route with.

## Handling HTTP verbs

It's common to have a single action do different things depending on the HTTP
verb. Lapis comes with some helpers to make writing these actions simple.
`respond_to` takes a table indexed by HTTP verb with a value of the function to
perform when the action receives that verb.

```lua
local lapis = require("lapis")
local app = lapis.Application()

app:match("create_account", "/create-account", respond_to({
  GET = function(self)
    return { render = true }
  end,
  POST = function(self)
    do_something(self.params)
    return { redirect_to = self:url_for("index") }
  end
}))
```

```moon
lapis = require "lapis"
import respond_to from require "lapis.application"

class App extends lapis.Application
  [create_account: "/create-account"]: respond_to {
    GET: => render: true

    POST: =>
      do_something @params
      redirect_to: @url_for "index"
  }
```

`respond_to` can also take a before filter of its own that will run before the
corresponding HTTP verb action. We do this by specifying a `before` function.
The same semantics of [before filters](#before-filters) apply, so if you call
<span class="for_moon">`@write`</span><span
class="for_lua">`self:write()`</span> then the rest of the action will not get
run.

```lua
local lapis = require("lapis")
local app = lapis.Application()

app:match("edit_user", "/edit-user/:id", respond_to({
  before = function(self)
    self.user = Users:find(self.params.id)
    if not self.user then
      self:write({"Not Found", status = 404})
    end
  end,
  GET = function(self)
    return "Edit account " .. self.user.name
  end,
  POST = function(self)
    self.user:update(self.params.user)
    return { redirect_to = self:url_for("index") }
  end
}))
```

```moon
lapis = require "lapis"
import respond_to from require "lapis.application"

class App extends lapis.Application
  "/edit_user/:id": respond_to {
    before: =>
      @user = Users\find @params.id
      @write status: 404, "Not Found" unless @user

    GET: =>
      "Edit account #{@user.name}..."

    POST: =>
      @user\update @params.user
      redirect_to: @url_for "index"
  }

```

On any `POST` request, regardless of whether `respond_to` is used or not, if
the `Content-type` header is set to `application/x-www-form-urlencoded` then
the body of the request will be parsed and all the parameters will be placed
into <span class="for_moon">`@params`</span><span
class="for_lua">`self.params`</span>.

<span class="for_lua">You may have also seen the `app:get()` and `app:post()`
methods being called in previous examples. These are wrappers around
`respond_to` that let you quickly define an action for a particular HTTP verb.
You'll find these wrappers for the most common verbs: `get`, `post`, `delete`,
`put`. For any others you'll need to use `respond_to`.</span>

```lua
app:get("/test", function(self)
  return "I only render for GET requests"
end)

app:delete("/delete-account", function(self)
  -- do something destructive
end)

```

## Before Filters

Sometimes you want a piece of code to run before every action. A good example
of this is setting up the user session. We can declare a before filter, or a
function that runs before every action, like so:

```lua
local app = lapis.Application()

app:before_filter(function(self)
  if self.session.user then
    self.current_user = load_user(self.session.user)
  end
end)

app:match("/", function(self)
  return "current user is: " .. tostring(self.current_user)
end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  @before_filter =>
    if @session.user
      @current_user = load_user @session.user

  "/": =>
    "current user is: #{@current_user}"
```

You are free to add as many as you like by calling <span
class="for_moon">`@before_filter`</span><span
class="for_lua">`app:before_filter`</span> multiple times. They will be run in
the order they are registered.

If a before filter calls the <span class="for_moon">`@write`</span><span
class="for_lua">`self:write()`</span> method then the action will be cancelled.
For example we can cancel the action and redirect to another page if some
condition is not met:

```lua
local app = lapis.Application()

app:before_filter(function(self)
  if not user_meets_requirements() then
    self:write({redirect_to = self:url_for("login")})
  end
end)

app:match("login", "/login", function(self)
  -- ...
end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  @before_filter =>
    unless user_meets_requirements!
      @write redirect_to: @url_for "login"

  [login: "/login"]: => ...
```

> <span class="for_moon">`@write`</span><span
> class="for_lua">`self:write()`</span> is what processes the return value of a
> regular action, so the same things you can return in an action can be passed
> to <span class="for_moon">`@write`</span><span
> class="for_lua">`self:write()`</span>

## Request Object

Every action is passed the *request object* as its first argument when called.
Because of the convention to call the first argument `self` we refer to the
request object as `self` when in the context of an action.

The request object has the following parameters:

* <span class="for_moon">`@params`</span><span class="for_lua">`self.params`</span> -- a table containing all the `GET`, `POST`, and URL parameters together
* <span class="for_moon">`@req`</span><span class="for_lua">`self.req`</span> -- raw request table (generated from `ngx` state)
* <span class="for_moon">`@res`</span><span class="for_lua">`self.res`</span> -- raw response table (used to update `ngx` state)
* <span class="for_moon">`@app`</span><span class="for_lua">`self.app`</span> -- the instance of the application
* <span class="for_moon">`@cookies`</span><span class="for_lua">`self.cookies`</span> -- the table of cookies, can be assigned to set new cookies. Only supports strings as values
* <span class="for_moon">`@session`</span><span class="for_lua">`self.session`</span> -- signed session table. Can store values of any type that can be JSON encoded. Is backed by cookies
* <span class="for_moon">`@options`</span><span class="for_lua">`self.options`</span> -- set of options that controls how the request is rendered to Nginx
* <span class="for_moon">`@buffer`</span><span class="for_lua">`self.buffer`</span> -- the output buffer
* <span class="for_moon">`@route_name`</span><span class="for_lua">`self.route_name`</span> -- the name of the route that matched the request if it has one


### @req

The raw request table <span class="for_moon">`@req`</span><span class="for_lua">`self.req`</span> wraps some of the data provided from `ngx`. Here is a list of the available properties.

* <span class="for_moon">`@req.headers`</span><span class="for_lua">`self.req.headers`</span> -- Request headers table
* <span class="for_moon">`@req.parsed_url`</span><span class="for_lua">`self.req.parsed_url`</span> -- Request parsed url. A table containing `scheme`, `path`, `host`, `port`, and `query` properties.
* <span class="for_moon">`@req.params_post`</span><span class="for_lua">`self.req.params_post`</span> -- Request POST parameters table
* <span class="for_moon">`@req.params_get`</span><span class="for_lua">`self.req.params_get`</span> -- Request GET parameters table


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
so we can tell what cookies have been assigned to during the action
because they will be directly in the <span
class="for_moon">`@cookies`</span><span class="for_lua">`self.cookies`</span>
table.

Thus, to set a cookie we just need to assign into the <span
class="for_moon">`@cookies`</span><span class="for_lua">`self.cookies`</span>
table:

```lua
app:match("/sets-cookie", function(self)
  self.cookies.foo = "bar"
end)
```

```moon
"/sets-cookie": =>
  @cookies.foo = "bar"
```

By default all cookies are given the additional attributes `Path=/; HttpOnly`
(which creates a [*session
cookie*](http://en.wikipedia.org/wiki/HTTP_cookie#Terminology)). You can
configure a cookie's settings by overriding the the `cookie_attributes`
function on your application. Here's an example that adds an expiration date to
cookies to make them persist:

```moon
date = require "date"

class App extends lapis.Application
  cookie_attributes: (name, value) =>
    expires = date(true)\adddays(365)\fmt "${http}"
    "Expires=#{expires}; Path=/; HttpOnly"
```

```lua
local date = require("date")
local app = lapis.Application()

app.cookie_attributes = function(self)
  local expires = date(true):adddays(365):fmt("${http}")
  return "Expires=" .. expires .. "; Path=/; HttpOnly"
end
```

The `cookie_attributes` method takes the request object as the first argument
(`self`) and then the name and value of the cookie being processed.

### Session

The <span class="for_moon">`@session`</span><span
class="for_lua">`self.session`</span> is a more advanced way to persist data
over requests. The content of the session is serialized to JSON and stored in
a specially named cookie. The serialized cookie is also signed with
your application secret so it can't be tampered with. Because it's serialized
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
-- config.lua
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

## Request Object Methods

###  `write(things...)`

Writes all of the arguments. A different action is done depending on the type
of each argument.

* `string` -- String is appended to output buffer
* `function` (or callable table) -- Function is called with the output buffer, result is recursively passed to `write`
* `table` -- key/value pairs are assigned into <span class="for_moon">`@options`</span><span class="for_lua">`self.options`</span>, all other values are recursively passed to `write`


In most circumstances it is unnecessary to call write as the return value of an
action is automatically passed to write. In before filters, write has the dual
purpose of writing to the output and cancelling any further actions from
running.

### `url_for(name_or_obj, params, query_params=nil, ...)`

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
  self:url_for("user_data", { user_id = 123, data_field = "height"})
end)
```

```moon
[user_data: "/data/:user_id/:data_field"]: =>
  "hi"

"/": =>
  -- returns: /data/123/height
  @url_for "user_data", user_id: 123, data_field: "height"
```

If `query_params` argument is supplied, then the value will be converted into
query parameters and appended to the end of the generated path.


```lua
-- returns: /data/123/height?sort=asc
self:url_for("user_data", { user_id = 123, data_field = "height"}, { sort = "asc" })
```

```moon
-- returns: /data/123/height?sort=asc
@url_for "user_data", { user_id: 123, data_field: "height"}, sort: "asc"
```

#### Passing an object to `url_for`

If `name_or_obj` is a table, then the `url_params` method is called on the
object. The arguments passed to `url_params` are the request, followed by all
the remaining arguments passed to `url_for`. The result of `url_params` is used
to call `url_for` again.

For example, consider a `Users` model that defines a `url_params` method:

```lua
local Users = Model:extend("users", {
  url_params = function(self, req, ...)
    return "user_profile", { id = self.id }, ...
  end
})
```

```moon
class Users extends Model
  url_params: (req, ...) =>
    "user_profile", { id: @id }, ...
```

We can now just pass an instance of `Users` directly to `url_for` and the path
for the `user_profile` route is returned:

```lua
local user = Users:find(100)
self:url_for(user)
-- could return: /user-profile/100
```

```moon
user = Users\find 100
@url_for user
-- could return: /user-profile/100
```

You might notice we passed `...` through the `url_params` method to the return
value. This allows the third `query_params` argument to still function:

```lua
local user = Users:find(1)
self:url_for(user, { page = "likes" })
-- could return: /user-profile/100?page=likes
```

```moon
user = Users\find 1
@url_for user, page: "likes"
-- could return: /user-profile/100?page=likes
```

#### Using the `url_key` method

The value of any parameter in `params` is a string then it is inserted into the
generated path as is. If the value is a table, then the `url_key` method is
called on it, and the return value is inserted into the path.

For example, consider a `Users` model which we've generated a `url_key` method
for:

```lua
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

If we wanted to generate a path to the user profile we might normally write
something like this:

```lua
local user = Users:find(1)
self:url_for("user_profile", {id = user.id})
```

```moon
user = Users\find 1
@url_for "user_profile", id: user.id
```

The `url_key` method we've defined lets us pass the `User` object directly as
the `id` parameter and it will be converted to the id:

```lua
local user = Users:find(1)
self:url_for("user_profile", {id = user})
```

```moon
user = Users\find 1
@url_for "user_profile", id: user
```

> The `url_key` method takes the name of the path as the first argument, so we
> could change what we return based on which route is being handled.

### `build_url(path, [options])`

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

## Render Options

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
class App extends lapis.Application
  "/hello": =>
    json: { hello: "world!" }
```





## Application Callbacks

Application callbacks are special methods that can be overridden in an
application that get called when certain kinds of requests needs to be handled.
Although they are functions stored on the application, they are called as if
they were regular actions, this means that the first argument to the function
is an instance of a request object.

### Default Action

When a request does not match any of the routes you've defined it will fall
back on running the default action. Lapis comes with a default action
pre-defined that looks like this:

```lua
app.default_route = function(self)
  -- strip trailing /
  if self.req.parsed_url.path:match("./$") then
    local stripped = self.req.parsed_url:match("^(.+)/+$")
    return {
      redirect_to = self:build_url(stripped, {
        status = 301,
        query = self.req.parsed_url.query,
      })
    }
  else
    self.app.handle_404(self)
  end
end
```

```moon
default_route: =>
  -- strip trailing /
  if @req.parsed_url.path\match "./$"
    stripped = @req.parsed_url.path\match "^(.+)/+$"
    redirect_to: @build_url(stripped, query: @req.parsed_url.query), status: 301
  else
    @app.handle_404 @
```

If it notices a trailing `/` on the end of the URL it will attempt to redirect
to a version without the trailing slash. Otherwise it will call the
`handle_404` method on the application.

This method, `default_route`, is just a normal method of your application. You
can override it to do whatever you like. For example, this adds logging:

```lua
app.default_route = function(self)
  ngx.log(ngx.NOTICE, "User hit unknown path " .. self.req.parsed_url.path)

  -- call the original implementaiton to preserve the functionality it provides
  return lapis.Application.default_route(self)
end
```

```moon
class App extends lapis.Application
  default_route: =>
    ngx.log ngx.NOTICE, "User hit unknown path #{@req.parsed_url.path}"
    @super!
```

You'll notice in the pre-defined version of `default_route` another method,
`handle_404`, is referenced. This is also pre-defined and looks like this:

```lua
app.handle_404 = function(self)
  error("Failed to find route: " .. self.req.cmd_url)
end
```

```moon
handle_404: =>
  error "Failed to find route: #{@req.cmd_url}"
```

This will trigger a 500 error and a stack trace on every invalid request. If
you want to make a proper 404 page this is where you would do it.

Overriding the `handle_404` method instead of `default_route` allows us to
create a custom 404 page while still keeping the trailing slash removal code.

Here's a simple 404 handler that just prints the text `"Not Found!"`

```lua
app.handle_404 = function(self)
  return { status = 404, layout = false, "Not Found!" }
end
```

```moon
class App extends lapis.Application
  handle_404: =>
    status: 404, layout: false, "Not Found!"
```

## Error Handler

Every action executed by Lapis is wrapped by [`xpcall`][1]. This ensures fatal
errors can be captured and a meaningful error page can be generated instead of
Nginx's default which is unaware of Lua code.

The error handler should only be used to capture fatal and unexpected errors,
expected errors are discussed in the [Exception Handling
guide]($root/reference/exception_handling.html)

Lapis comes with an error handler pre-defined that extracts information about
the error and renders the template `"lapis.views.error"`. This error page
contains a stack trace and the error message.

If you want to have your own error handling logic you can override the method
`handle_error`:

```lua
app.handle_error = function(self, err, trace)
  ngx.log(ngx.NOTICE, "There was an error! " .. err .. ": " ..trace)
  lapis.Application.handle_error(self, err, trace)
end
```

```moon
class App extends lapis.Application
  handle_error: (err, trace) =>
    ngx.log ngx.NOTICE, "There was an error! #{err}: #{trace}"
    super!
```

The [`lapis-exceptions`][2] module provides a default error handler that
records errors in a database and can email you when they happen.

[1]: http://www.lua.org/manual/5.1/manual.html#pdf-xpcall
[2]: https://github.com/leafo/lapis-exceptions

