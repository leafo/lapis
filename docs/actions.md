{
  title: "Requests and Actions"
}
# Requests and Actions

Every HTTP request that is handled by Lapis follows the same basic flow after
being handed off from processing server. The first step is routing. A *route*
is a pattern that a URL must match. When you define a route you also include an
*action*. An action is a regular Lua/MoonScript function that will be called if
the associated route matches.

All actions are invoked with one argument, a [*request
object*](#request-object). The request object is where you'll store all the
data you want to share between your actions and views. Additionally, the
request object is your interface to the webserver on how the result is sent to
the client.

The return value of the action is used to render the output. A string return
value will be rendered to the browser directly. A table return value will be
used as the [*render options*](#render-options). If there is more than one
return value, all of them are merged into the final result. You can return both
strings and tables to control the output.

If there is no route that matches the request then the default route handler is
executed, read more in [*application callbacks*](#application-configuration/callbacks).

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
The parameter will match all characters excluding `/` (in the general case):


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

A splat is another kind of pattern that will match as much as it can, including
any `/` characters.  The splat is stored in a `splat`  named parameter in the
`params` table of the request object. It's just a single `*`

```lua
app:match("/browse/*", function(self)
  print(self.params.splat)
end)
app:match("/user/:name/file/*", function(self)
  print(self.params.name, self.params.splat)
end)
```

```moon
lapis = require "lapis"

class App extends lapis.Application
  "/browse/*": =>
    print @params.splat

  "/user/:name/file/*": =>
    print @params.name, @params.splat
```

If you put any text directly after the splat or the named parameter it will not
be included in the named parameter. For example you can match URLs that end in
`.zip` with `/files/:filename.zip`

### Optional route components

Parentheses can be used to make a section of the route optional:

    /projects/:username(/:project)

The above would match either `/projects/leafo`  or `/projects/leafo/lapis`. Any
parameters within optional components that don't match will have a value of
`nil` from within the action.

These optional components can be nested and chained as much as you like:

    /settings(/:username(/:page))(.:format)

### Parameter character classes

A character class can be applied to a named parameter to restrict what
characters can match. The syntax modeled after Lua's pattern character classes.
This route will make sure the that `user_id` named parameter only contains
digits:

    /user/:user_id[%d]/posts

And this route would only match hexadecimal strings for the `hex` parameter.

    /color/:hex[a-fA-F%d]

### Route precedence

Routes are searched first by precedence, then by the order they were defined.
Route precedence from highest to lowest is:

* Literal routes `/hello/world`
* Variable routes `/hello/:variable`
  * Each additional `:variable` will decrease the precedence of the route
* Splat routes routes `/hello/*`
  * Each additional splat will *increase* the precedence of the route. Given the routes `/hello/*spat` and `/hello/*splat/world/*rest`, the second one will be checked before the first.

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

app:match("user_profile", "/user/:name", function(self)
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

[Read more about `url_for`](#request-object-methods/url_for) to see the
different ways to generate URLs to pages.

## Handling HTTP verbs

It's common to have a single action do different things depending on the HTTP
verb. Lapis comes with some helpers to make writing these actions simple.
`respond_to` takes a table indexed by HTTP verb with a value of the function to
perform when the action receives that verb.

```lua
local lapis = require("lapis")
local respond_to = require("lapis.application").respond_to
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
local respond_to = require("lapis.application").respond_to
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

When a request is processed, the action function is passed a `request object`
as its first argument. Because of Lua's convention to call the first argument
`self`, we refer to the request object as `self` when in the context of an
action.

The request object contains the following fields:

$options_table{
  show_default = false,
  {
    name = $self_ref{"route_name"},
    description = "The name of the route that was matched during routing, if available",
    example = $dual_code{[[
      app\match "my_page", "/my-page", =>
        assert @route_name == "my_page"
    ]]}
  },
  {
    name = $self_ref{"params"},
    description = "A table containing all request parameters merged together, including query parameters and form-encoded parameters from the body of the request. See [Request Parameters](#request_parameters) for more details."
  },
  {
    name = $self_ref{"GET"},
    description = "A table containing only the query parameters included in the URL (eg. `?hello=world`). Note that this field is included for any request with URL query parameters, regardless of the HTTP verb used for the request."
  },
  {
    name = $self_ref{"POST"},
    description = "A table containing only the form encoded parameters included in the body of the request. Note that this field is included for any request with form data in the body, regardless of the HTTP verb."
  },
  {
    name = $self_ref{"req"},
    description = "An object containing the internal request information generated by the underlying server processing the request. The full structure of this object is intentionally undocumented. Only resort to referencing it if you need server specific data not available elsewhere."
  },
  {
    name = $self_ref{"res"},
    description = "An object used to used to generate the response for the client at the end of the request. The structure of this object is specific to the underlying server processing the request, and is intentionally undocumented."
  },
  {
    name = $self_ref{"app"},
    description = "The instance of the `lapis.Application` that is responding to requests. Note that a single instance is shared across many requests, but there may be multiple instances if there are multiple worker processes handling requests."
  },
  {
    name = $self_ref{"cookies"},
    description = "A proxy table that can be used to read any cookies that have been included with the request. New cookies can be stored for the response  by setting them on this table. Only strings are supported as field names and values. See [Cookies](#request-object/cookies) for more information.",
    example = $dual_code{[[
      app\match "/", =>
        print @cookies.last_seen
        @cookies.current_date = tostring os.time
    ]]}
  },
  {
    name = $self_ref{"session"},
    description = "A proxy table for reading and writing the dynamically created session object. A session object is a signed, json-encoded object that is transferred via cookies. Because it is signed, it's safe to include data in it that you know the end user can not tamper with. See [Session](#request-object/session) for more information."
  },
  {
    name = $self_ref{"options"},
    description = "A table of options that will controls how the request is rendered. It is populated by calls to `write`, and also set by the return value of your action. See [Render Options](#render-options) for more information."
  },
  {
    name = $self_ref{"buffer"},
    description = "The output buffer containing the fragments of text that will be written to the client after all processing is complete. Typically you'll not need to touch this manually. It is populated via the `write` method."
  }
}

### `request.req`

The raw request table $self_ref{"req"} contains data from the request provided
by the underlying server. The format of this data may be server specific.

* $self_ref{"headers"} -- Request headers table
* $self_ref{"parsed_url"} -- A table generated containing all the components of the requesting URL. Contains fields like `scheme`, `path`, `host`, `port`, and `query`
* $self_ref{"params_get"} -- Unprocessed table of parameters from the query string of the requesting URL
* $self_ref{"params_post"} -- Unprocessed table of parameters from the body of the request

### Cookies

The <span class="for_moon">`@cookies`</span><span
class="for_lua">`self.cookies`</span> table in the request lets you read and
write cookies.

The cookies object, $self_ref{"cookies"}, is a proxy object. It supports
reading existing cookies by indexing the object by name, and writing new
cookies by writing them to the table. When iterating, the cookies object will
always appear as an empty table. The initial cookies are stored in the
`__index` of the metatable.

```lua
app:match("/reads-cookie", function(self)
  print(self.cookies.foo)
end)


app:match("/sets-cookie", function(self)
  self.cookies.foo = "bar"
end)
```

```moon
class App extends lapis.Application
  "/reads-cookie": =>
    print @cookies.foo

  "/sets-cookie": =>
    @cookies.foo = "bar"
```

All new cookies created are given the default attributes `Path=/; HttpOnly`
(know as a [*session
cookie*](http://en.wikipedia.org/wiki/HTTP_cookie#Terminology)). You can
configure a cookie's settings by overriding the the `cookie_attributes` method
on your application. Here's an example that adds an expiration date to cookies
to make them persist:

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

The $self_ref{"session"} is a more advanced way to persist data over requests.
The content of the session is serialized to JSON and stored in a specially
named cookie. The serialized cookie is also signed with your application secret
so it can't be tampered with. Because it's serialized with JSON you can store
nested tables and other primitive values.

The session object, $self_ref{"session"}, is a proxy object. It supports
reading values by indexing the object, and writing new session fields by
writing to the table. When iterating, the session object will always appear as
an empty table.

The session object can be manipulated the same way as the cookies object:

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
variable](configuration.html). Sessions are signed with your
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

## Request Parameters

The request object contains a few fields to help you access the user-supplies
parameters sent with the request. Parameters are loaded by default from the
following sources:

* URL parameters -- When using a route that has a named variable. A route `/users/:id` will create a parameters named `id`
* Body parameters -- For request methods that support a body, like `POST` and `PUT`, the body will automatically be parsed if the content type is `application/x-www-form-urlencoded` or `multipart/form-data`
* Query parameters -- Parameters included at the end of a request URL following the `?`. `/users?filter=blue` will create a parameter called filter with the value `"blue"`

The `@params` object is a concatenation of all the default loaded parameters
listed above. URL parameters have the highest precedence, followed by body
parameters, then query parameters. This means that an `:id` URL parameters will
not be overwritten by an `?id=` query parameter.

> Headers and cookies are also accessible on the request object but they are
> not included in the parameters object.

The body of the request is only parsed if the content type is
`application/x-www-form-urlencoded` or `multipart/form-data`. For requests that
use another content type, like `json`, you can use the `json_params` helper
function to parse the body.

See [How can I read JSON HTTP body?]($root/reference/quick_reference.html#how-can-i-read-json-http-body).

### Boolean parameters

A query parameter without a value is treated as a boolean parameter and will
have the value `true`.

`/hello?hide_description&color=blue` → `{ hide_description = true, color = "blue"}`

### Nested Parameters

It is common to use the `[]` syntax within a parameter name to represent nested
data within parameters. Lapis supports expanding this syntax for simple
key, value objects:


    /hello?upload[1][name]=test.txt&upload[2][name]=file.png →

    {
      upload = {
        ["1"] = { name = "test.txt" }, -- note that strings are not converted to numbers!
        ["2"] = { name = "file.png"}
      }
    }

> Lapis does not support the empty `[]` syntax that you may have seen in other
> frameworks for creating arrays. Only simple object expansion is supported.
> Generally we encourage the application developer to do the parsing since
> advanced parameter can unknowingly introduce bugs.

### Parameters Types & Limits

The value of a parameter can either be a string, `true`, or a simple table. No complex
parsing or validation is done on parameters, it's the responsibility of the
application creator to verify and sanitize any parameters. For example, if you're
expecting a number, you will need to convert the value to a number using
something like the Lua builtin `tonumber`.

Lapis provides a [validation module]($root/reference/input_validation.html) to
help with verifying that user supplied data matches a set of constraints that
you provide.

Duplicate parameter names are overwritten by subsequent values. Note that due
to hash table ordering, the final value may not be consistent so we recommend
avoid setting the same parameters multiple times.

When using Nginx, a default limit of 100 parameters are parsed by default from
the body and query. This is to prevent malicious users from overloading your
server with a large amount of data.

> Storing or processing user input as a string? We highly recommend adding
> limits on the max length of the string and trimming whitespace from the
> sides. Additionally, verifying that the data is a valid Unicode string can
> prevent any processing errors by your database.

## Request Object Methods

### `request:write(things...)`

Writes all of the arguments to the output buffer or options table. A different
action is done depending on the type of each argument.

* `string` -- String is appended to output buffer
* `function` (or callable table) -- Function is called with the output buffer, result is recursively passed to `write`
* `table` -- key/value pairs are assigned into $self_ref{"options"}, all other values are recursively passed to `write`

In most circumstances it is unnecessary to call write as the return value of an
action is automatically passed to write. In before filters, write has the dual
purpose of writing to the output and cancelling any further actions from
running.

### `request:url_for(name_or_obj, params, query_params=nil, ...)`

Generates a URL for `name_or_obj`.

> `url_for` is a bit of a misnomer since it typically generates a path to the
> requested page. If you want to get the entire URL you can combine this
> function with `build_url`.

If `name_or_obj` is a string, then the route of that name is looked up and
filled using the values in params. If no route exists then an error is thrown.

Given the following routes:


```lua
app:match("index", "/", function()
  -- ...
end)

app:match("user_data", "/data/:user_id/:data_field", function()
  -- ...
end)
```

```moon
class App extends lapis.Application
  [index: "/"]: => -- ..
  [user_data: "/data/:user_id/:data_field"]: => -- ...
```

URLs to the pages can be generated like this:

```lua
-- returns: /
self:url_for("index")

-- returns: /data/123/height
self:url_for("user_data", { user_id = 123, data_field = "height"})
```

```moon
-- returns: /
@url_for "index"

-- returns: /data/123/height
@url_for "user_data", user_id: 123, data_field: "height"
```

If the third argument, `query_params`, is supplied, it will be converted into
query parameters and appended to the end of the generated URL. If the route
doesn't take  any parameters in the URL then `nil`, or empty object, must be
passed as the second argument:

```lua
-- returns: /data/123/height?sort=asc
self:url_for("user_data", { user_id = 123, data_field = "height"}, { sort = "asc" })

-- returns: /?layout=new
self:url_for("index", nil, {layout = "new"})
```

```moon
-- returns: /data/123/height?sort=asc
@url_for "user_data", { user_id: 123, data_field: "height"}, sort: "asc"

-- returns: /?layout=new
@url_for "index", nil, layout: "new"
```

Any optional components of the route will only be included if all of the
enclosed parameters are provided. If the optional component does not have any
parameters then it will never be included.

Given the following route:

```lua
app:match("user_page", "/user/:username(/:page)(.:format)", function(self)
  -- ...
end)
```

```moon
class App extends lapis.Application
  [user_page: "/user/:username(/:page)(.:format)"]: => -- ...
```

The following URLs can be generated:

```lua
-- returns: /user/leafo
self:url_for("user_page", { username = "leafo" })

-- returns: /user/leafo/projects
self:url_for("user_page", { username = "leafo", page = "projects" })

-- returns: /user/leafo.json
self:url_for("user_page", { username = "leafo", format = "json" })

-- returns: /user/leafo/code.json
self:url_for("user_page", { username = "leafo", page = "code", format = "json" })
```

```moon
-- returns: /user/leafo
@url_for "user_page", username: "leafo"

-- returns: /user/leafo/projects
@url_for "user_page", username: "leafo", page: "projects"

-- returns: /user/leafo.json
@url_for "user_page", username: "leafo", format: "json"

-- returns: /user/leafo/code.json
@url_for "user_page", username: "leafo", page: "code", format: "json"
```

If a route contains a splat, the value can be provided via the parameter named
`splat`:

```lua
app:match("browse", "/browse(/*)", function(self)
  -- ...
end)
```

```moon
class App extends lapis.Application
  [browse: "/browse(/*)"]: => -- ...
```

```lua
-- returns: /browse
self:url_for("browse")

-- returns: /browse/games/recent
self:url_for("browse", { splat = "games/recent" })
```

```moon
-- returns: /browse
@url_for "browse"

-- returns: /browse/games/recent
@url_for "browse", splat: "games/recent"
```

#### Passing an object to `url_for`

If `name_or_obj` is a table, then the `url_params` method is called on that
table, and the return values are passed to `url_for`.

The `url_params` method takes as arguments the `request` object, followed by
anything else passed to `url_for` originally.

It's common to implement `url_params` on models, giving them the ability to
define what page they represent. For example, consider a `Users` model that
defines a `url_params` method, which goes to the profile page of the user:

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

### `request:build_url(path, [options])`

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


The following options are supported:

$options_table{
  {
    name = "scheme",
    default = "Current scheme",
    description = "eg. `http`, `https`"
  },
  {
    name = "host",
    default = "Current host"
  },
  {
    name = "port",
    default = "Current port",
    description = "If port matches the default for the scheme (eg. 80 for http) then it will be left off"
  },
  {
    name = "fragment",
    description = "Part of the URL following the `#`. Must be string"
  },
  {
    name = "query",
    description = "Part of the URL following the `?`. Must be string"
  }
}

### `request:flow(module_name)`

Loads a flow by `module_name` with the `flows_prefix` on the current request
object. If the flow with that name had been previously loaded, then the
existing flow instance is returned.

### `request:html(fn)`

Returns a new function that implements the buffer writer interface for
rendering the contents of `fn` as an HTML scoped function. Suitable for
returning from an action.

### `request:get_request()`

This function returns `self`. This method is useful in scenarios where the
request object is being proxied, and you wish to get a direct access to the
instance of the request object for mutation. Examples include within flows and
within widgets where the request object is embedded into the *helper chain*.

## Render Options

Render options are set by explicit calls to `write` or by the return value of
the action function. They are accumulated in the $self_ref{"options"} field of
the request object. Typically an action function does not generate the response
directly, but sets the options to be used by Lapis during the rendering phase
of the request which happens immediately after executing the action.

For example, in the following action the `render` and `status` fields are used
to set the HTTP status response code, and specify a view by name to be used to
generate the response body.


```lua
app:match("/", function(self)
  return { render = "error", status = 404}
end)
```

```moon
"/": => render: "error", status: 404
```

Here are the options that can used to control the how the response is generated:

$options_table{
  {
    name = "status",
    description = "Sets HTTP status code of the response (eg. 200, 404, 500, ...)",
    default = "`200`",
    example = dual_code{[[
      app\match "/", => status: 201
    ]]}
  },
  {
    name = "render",
    description = "Renders a view to the output buffer during the rendering phase of the request. If the value is `true` then the name of the route is used as the view name. Otherwise the value must be a string or a view class. When a string is provided as the view name, it will be loaded as a module with `require` using the full module name `{app.views_prefix}.{view_name}`",
    example = dual_code{[[
      app\match "index", "/", => render: true, "This loads views.index"
      app\match "/page1", => render: "my_view"
      app\match "/page2", => render: require "helpers.my_view"
    ]]}
  },
  {
    name = "content_type",
    description = "Sets the `Content-type` header",
    example = dual_code{[[
      app\match "/plain", => "Plain text", layout: false, content_type: "text/plain"
    ]]}
  },
  {
    name = "headers",
    description = "A table of headers to add to the response"
  },
  {
    name = "json",
    description = "Renders the the JSON encoded value of the option. The content type is set to `application/json` and the layout is disabled.",
    example = $dual_code{[[
      app\match "/plain", =>
        json: { name: "Hello world!", ids: {1,2,3} }
    ]]}
  },
  {
    name = "layout",
    description = "Overrides the layout from the application default. Set to `false` to entirely disable the layout. Can either be a renderable object (eg. a Widget or etlua template), or a string. When a string is provided it is used as the view name, it will be loaded as a module with `require` using the full module name `{app.views_prefix}.{view_name}`",
    example = dual_code{[[
      app\match "/none", => "No layout here!", layout: false, content_type: "text/plain"
      app\match "/mobile", => "Custom layout", layout: "mobile_layout"
    ]]}
  },
  {
    name = "redirect_to",
    description = "Sets status to 302 and uses the value of this option for the `Location` header. Both relative and absolute URLs can be used. (Combine with `status` to perform 301 redirect)",
    example = dual_code{[[
      app\match "/old", => redirect_to: @url_for("new")
      app\match "new", "/new", => "You made it!"
    ]]}
  },
  {
    name = "skip_render",
    description = "Set to `true` to cause Lapis to skip it's entire rendering phase (including content, status, headers, cookies, sessions, etc.). Use this if you manually write the request response in the action method (using low level `ngx.print`, `ngx.header` or equivalent). This can be used to implement streaming output, as opposed to Lapis' default buffered output.",
    example = dual_code{[[
      app\match "/stream", =>
        ngx.print "this will..."
        ngx.sleep 1
        ngx.print "stream to you"
        ngx.sleep 1
        ngx.print "slowly"

        skip_render: true
    ]]}
  }

}

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


## Application Configuration

These fields are designed to be overwritten by the application creator to
configure how the application functions. These fields can either be overwridden
on the instance, of by setting the instance fields when creating a new
Application class.

### `application.layout`

Specifies a view that will be used to wrap the content of the results response
in. A layout is always rendered around the result of the action's render unless
`layout` is set to false, or a renderer with a separate content type is used
(eg. `json`)

Can either be an instance of a view or a string. When a string is provided, the
layout is loaded as a module via the `require` using the module name
`{views_prefix}.{layout_name}`.

Default `require "lapis.views.layout"`

### `application.error_page`

View used to render an unrecoverable error in the [default
`handle_error`](#application-configuration/callbacks/handle_error) callback.
The value of this field is passed directly to Render Option `render`, enabling
the use of specifying the page by view name or directly by a widget or
template.

Default `require "lapis.views.error"`

### `application.views_prefix`

A prefix appended to the view name (joined by `.`) whenever a view is
specified by string to determine the full module name to require.

Default `"views"`

### `application.actions_prefix`

A prefix appended to the action name (joined by `.`) whenever an action is
specified by string to determine the full module name to require.

Default `"actions"`

### `application.flows_prefix`

A prefix appended to the flow name (joined by `.`) whenever a flow is specified
by string to determine the full module name to require.

Default `"flows"`

### `application.Request`

The class that will be used to instantiate new request objects when dispatching
a request. Default `require "lapis.request"`

### Callbacks

Application callbacks are special methods that can be overridden to handle
special cases and provide additional configuration.

Although they are functions stored on the application, they are called like
like actions, meaning the first argument to the function is an instance of a
request object.

#### `application:default_route()`

When a request does not match any of the routes you've defined, the
`default_route` method will be called to create a response.

A default implementation is provided:

```lua
function app:default_route()
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

The default implementation will check for excess trailing `/` on the end of the
URL it will attempt to redirect to a version without the trailing slash.
Otherwise it will call the `handle_404` method on the application.

This method, `default_route`, is a normal method of your application. You can
override it to do whatever you like. For example, this adds logging:

```lua
function app:default_route()
  ngx.log(ngx.NOTICE, "User hit unknown path " .. self.req.parsed_url.path)

  -- call the original implementaiton to preserve the functionality it provides
  return lapis.Application.default_route(self)
end
```

```moon
class App extends lapis.Application
  default_route: =>
    ngx.log ngx.NOTICE, "User hit unknown path #{@req.parsed_url.path}"
    super!
```


#### `application:handle_404()`

In the default `default_route`, the method `handle_404` is called when the path
of the request did not match any routes.

A default implementation is provided:

```lua
function app:handle_404()
  error("Failed to find route: " .. self.req.request_uri)
end
```

```moon
handle_404: =>
  error "Failed to find route: #{@req.request_uri}"
```

This will trigger a 500 error and a stack trace on every invalid request. If
you want to make a proper 404 page this is where you would do it.

Overriding the `handle_404` method instead of `default_route` allows us to
create a custom 404 page while still keeping the trailing slash removal code.

Here's a simple 404 handler that just prints the text `"Not Found!"`

```lua
function app:handle_404()
  return { status = 404, layout = false, "Not Found!" }
end
```

```moon
class extends lapis.Application
  handle_404: =>
    status: 404, layout: false, "Not Found!"
```

#### `application:handle_error(err, trace)`

Every action executed by Lapis is wrapped by [`xpcall`][1]. This ensures fatal
errors can be captured and a meaningful error page can be generated instead of
the server's default error page, which may not be useful.

The error handler should only be used to capture fatal and unexpected errors,
expected errors are discussed in the [Exception Handling
guide]($root/reference/exception_handling.html)

Lapis comes with an error handler pre-defined that extracts information about
the error and renders the template specified by `application.error_page`. This error page
contains a stack trace and the error message.

If you want to have your own error handling logic you can override the method
`handle_error`:

```lua
-- config.custom_error_page is made up for this example
function app:handle_error(err, trace)
  if config.custom_error_page then
    return { render = "my_custom_error_page" }
  else
    return lapis.Application.handle_error(self, err, trace)
  end
end
```

```moon
-- config.custom_error_page is made up for this example
class App extends lapis.Application
  handle_error: (err, trace) =>
    if config.custom_error_page
      { render: "my_custom_error_page" }
    else
      super err, trace
```

The request object, or `self`, passed to the error handler is not the one that
was created for the request that failed. Lapis provides a new one since the
existing one maybe have been partially written to when it failed.

You can access the original request object with <span
class="for_moon">`@original_request`</span><span
class="for_lua">`self.original_request`</span>

Lapis' default error page shows an entire stack trace, so it's recommended to
replace it with a custom one in your production environments, and log the
exception in the background.

The [`lapis-exceptions`][2] module augments the error handler to records errors
in a database. It can also email you when there's an exception.




## Application Methods

A Lapis Application can be built either by subclassing it (via MoonScript or
`extend`), or by creating an instance of it and calling the appropriate methods
or overriding the appropriate fields.

### `application:match([route_name], route_patch, action_fn)`

Adds a new route to the route group contained by the application. See above for
more information on registering actions. Note that routes are inheritance by
the inheritance change of the application object.

You can overwrite a route by re-using the same route name, or path, and that
route will take precedence over one defined further up in the inheritance
change.

Class approach:

```lua
local app = lapis.Application:extend()

app:match("index", "/index", function(self) return "Hello world!" end)
app:match("/about", function(self) return "My site is cool" end)
```

```moon
class extends lapis.Application
  @match "index", "/index", => "Hello world!"
  @match "/about", => "My site is cool"
```

Instance approach:

$dual_code{[[
app = lapis.Application!

app\match "index", "/index", => "Hello world!"
app\match "/about", => "My site is cool"
]]}


### `application:get(...)`

Shortcut method for adding route for a specific HTTP verb by utilizing the
`respond_to` via `match`. Same arguments as `match`.

### `application:post(...)`

Shortcut method for adding route for a specific HTTP verb by utilizing the
`respond_to` via `match`. Same arguments as `match`.

### `application:delete(...)`

Shortcut method for adding route for a specific HTTP verb by utilizing the
`respond_to` via `match`. Same arguments as `match`.

### `application:put(...)`

Shortcut method for adding route for a specific HTTP verb by utilizing the
`respond_to` via `match`. Same arguments as `match`.

### `application:enable(feature)`

Loads a module named `feature` using `require`. If the result of that module is
callable, then it will be called with one argument, `application`.

### `application:before_filter(fn)`

Appends a before filter to the chain of filters for the application. Before
filters are applied in the order they are added. They receive one argument, the
request object.

A before filter is a function that will run before the action's function. If a
`write` takes place in a before filter then the request is ended after the
before filter finishes executing. Any remaining before filters and the action
function are not called.

See [Before Filters](#before-filters) for more information.

### `application:include(other_app, opts={})`

Copies all the routes from `other_app` into the current app. `other_app` can be
either an application class or an instance. If there are any before filters in
`other_app`, every action of `other_app` will be be wrapped in a new function
that calls those before filters before calling the original function.

Options can either be provided in the arugment `opts`, or will be pulled from
`other_app`, with precedence going to the value provided in `opts` if provided.

Note that application instance configuration like `layout` and `views_prefix`
are not kept from the included application.

$options_table{
  {
    name = "path",
    description = "If provided, every path copied over will be prefixed with the value of this option. It should start with a `/` and a trailing slash should be inlcuded if desired."
  },
  {
    name = "name",
    description = "If provided, every route name will be prefixed with the value of the this option. Provide a trailing `.` if desired."
  }
}

### `application:find_action(name, resolve=true)`

Searches the inheritance chain for the first action specified by the route
name, `name`.

Returns the `action` value and the route path object if an action could be
found. If `resolve` is true the action value will be loaded if it's a deferred
action like `true` or a module name

Returns `nil` if no action could be found.

### `Application:extend([name], fields={}, [init_fn])`

Creates a subclass of the Application class. This method is only available on
the class object, not the instance. Instance fields can be provided as via the
`fields` arugment or by mutating the returned metatable object.

This method returns the newly created class object, and the metatable for any
instances of the class.

```lua
local MyApp, MyApp_mt = lapis.Application:extend("MyApp", {
  layout = "custom_layout",
  views_prefix = "widgets"
})

function MyApp_mt:handle_error(err)
  error("oh no!")
end

-- note that `match` is a class method, so MyApp_mt is not used here
MyApp:match("home", "/", function(self) return "Hello world!" end)
```
 
[1]: http://www.lua.org/manual/5.1/manual.html#pdf-xpcall
[2]: https://github.com/leafo/lapis-exceptions
