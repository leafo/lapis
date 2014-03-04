### A Simple MoonScript Application

Instead of making `web.lua`, we'll actually make `web.moon` and let the
[MoonScript compiler][4] automatically generate the Lua file.

Create `web.moon`:

```moon
lapis = require "lapis"
lapis.serve class extends lapis.Application
  "/": => "Hello World!"
```

That's it! `lapis.serve` takes an application class to serve the request with.
So we create an anonymous class that extends from `lapis.Application`.

The members of our class make up the patterns that can be matched against the
route and the resulting action that happens. In this example, the route `"/"`
is matched to a function that returns `"Hello World!"`

The return value of an action determines what is written as the response. In
the simplest form we can return a string in order to write a string.

You can read more about what an action can return in [Request Objects](#request-object-request-options).

> Don't forget to compile the `.moon` files. You can watch the current
> directory and compile automatically with `moonc -w`.

## Starting The Server

To start your server you can run `lapis server`. The `lapis` binary will
attempt to find your OpenResty instalation. It will search the following
directories for an `nginx` binary. (The last one represents anything in your
`PATH`)

    "/usr/local/openresty/nginx/sbin/"
    "/usr/sbin/"
    ""

> Remember that you need OpenResty and not a normal installation of Nginx.
> Lapis will ignore regular Nginx binaries.

So go ahead and start your server:

```bash
$ lapis server
```

Assuming there are no errors we can now navigate to <http://localhost:8080/> to
see our application.

## Lapis Applications

When we refer to a Lapis application we are talking about a class that extends
from `lapis.Application`. The properties of the application make up the routes
the application can serve and the actions it will perform.

If a property name is a string and begins with a `"/"` or the property is a
table then it defines a route. All other properties are methods of the
application.

Let's start with the basic application from above:

```moon
lapis = require "lapis"
lapis.serve class extends lapis.Application
  "/": => "Hello World!"
```

[Named routes](#lapis-applications-named-routes) are constructed using a table as a property name.

### URL Parameters

Routes can contain special patterns that match parts of the URL and put them
into a request parameter.

Named parameters are a `:` followed by a name. They match all characters
excluding `/`.

```moon
"/user/:name": => "Hello #{@params.name}"
```

If we were to go to the path `"/user/leaf"`, `@params.name` would be set to
`"leaf"`.

`@params` holds all the parameters to the action. This is a concatenation of
the URL parameters, the GET parameters and the POST parameters.

A splat will match all characters and is represented with a `*`. Splats are not
named. The value of the splat is placed into `@params.splat`

```moon
"/things/*": => "Rest of the url: #{@params.splat}"
```

### The Action

An action is the function that is called in reponse to a route matching the
URL. In the above example it uses a fat arrow, `=>`, so you might think that
`self` is an instance of application. It's actually an instance of the
`Request`, a class that abstracts the request from Nginx.

As we've already seen, the request holds all the parameters in `@params`.

We can the get the distinct parameters types using `@GET`, `@POST`, and
`@url_params`.

We can also access the instance of the application with `@app`, and the raw
request and response with `@req` and `@res`.

### Named Routes

It's useful in websites to give names to your routes so when you need to
generate URLs in other parts of you application you don't have to manually
construct them.

If the key of the action is a table with a single pair, then the key of that
table is the name and the value is the pattern. MoonScript gives us convenient
syntax for representing this:

```moon
[index: "/"]: =>
  @url_for "user_profile", name: "leaf"

[user_profile: "/user/:name"]: =>
  "Hello #{@params.name}, go home: #{@url_for "index"}"
```

We can then generate the paths using `@url_for`. The first argument is the
named route, and the second optional argument is the parameters to the route
pattern.

### Before Filters

Sometimes you want a piece of code to run before every action. A good example
of this is setting up the user session. We can declare a before filter, or a
function that runs before every action, like so:

```moon
class App extends lapis.Application
  @before_filter =>
    if @session.user
      @current_user = load_user @session.user

  "/": =>
    "current user is: #{@current_user}"
```

You are free to add as many as you like by calling `@before_filter`
multiple times. They will be run in the order they are registered.

If a before filter calls the `@write` method then the action will be canceled.
For example we can cancel the action and redirect to another page if some
condition is not met:

```moon
class App extends lapis.Application
  @before_filter =>
    unless user_meets_requirements!
      @write redirect_to: @url_for "login"

  "/": =>
    "Welcome in"
```

### Handling HTTP verbs

It's common to have a single action do different things depending on the HTTP
verb. Lapis comes with some helpers to make writing these actions simple.
`respond_to` takes a table indexed by HTTP verb with a value of the function to
perform when the action receives that verb.

```moon
import respond_to from require "lapis.application"

class App extends lapis.Application
  [create_account: "/create_account"]: respond_to {
    GET: => render: true

    POST: =>
      create_user @params
      redirect_to: @url_for "index"
  }
```

`respond_to` can also take a before filter of its own that will run before the
corresponding HTTP verb action. We do this by specifying a `before` function.
The same semantics of [before filters](#lapis-applications-before-filters)
apply, so if you call `@write` then the rest of the action will not get run.

```moon
class App extends lapis.Application
  "/edit_user/:id": respond_to {
    before: =>
      @user = Users\find @params.id
      @write status: 404, "Not Found" unless @user

    GET: =>
      "Welcome " .. @user.name

    POST: =>
      @user\update @params.user
      redirect_to: @url_for "index"
  }

```

### Sub-Applications

As your web application becomes more complex it helps to break it apart into
multiple sub-applications. Lapis doesn't place any rules on how you divide your
application, instead it facilities the combination of applications.

#### `@include(other_application, [opts])`

Let's say we've got a separate application for handling users:

```moon
-- applications/users.moon
lapis = require "lapis"

class UsersApplication extends lapis.Application
  [login: "/login"]: do_login!
  [logout: "/logout"]: do_logout!
```

We can include this application into our main one:

```moon
-- app.moon
lapis = require "lapis"

class extends lapis.Application
  @include require "applications.users"

  [index: "/"]: =>
    @html ->
      a href: @url_for("login"), "Log in"
```

In this example `applications/user.moon` is a module that returns the
sub-application. The `include` class method is used to load this application
into our root one. `include` copies all the routes of the other application,
leaving the original untouched.

Before filters of the sub-application are kept associated with the actions from
that application.

In addition to passing in an actual application object, you can also pass in a
string and it will `require`d automatically. The above include statement could
be rewritten as:

```moon
class extends lapis.Application
  @include "applications.users"
  -- ...
```

`include` takes an optional second argument, a table of options. The following
options are available:

* `path` -- The patterns of the routes copied are prefixed with `path`
* `name` -- The names of all the routes copied are prefixed with `name`

For example, we might prefix the users application. Notice how the name of the
route and its URL are different:

```moon
class extends lapis.Application
  @include require("applications.users"), path: "/users", name: "user_"

  "/": =>
    @url_for("user_login") -- returns "/users/login"
```

Instead of passing the `path` and `name` prefixes `include`, you can set their
default values on the application. These only apply when the application is
included, and have no effect when the application is served.

```moon
class UsersApplication extends lapis.Application
  @path: "/users"
  @name: "user_"

  -- etc...
```

### Default Action

When a request does not match an action that you have defined a pattern for it
will fall back on running the default action. The default action that Lapis
provides looks like this:

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
to a version without the trailing slash. Other wise it will call the
`handle_404` method on the application.

This method, `default_route`, is just a normal method on your application. You
can override it to do whatever you like. For example this adds logging:

```moon
class extends lapis.Application
  default_route: =>
    ngx.log ngx.NOTICE, "User hit unknown path #{@req.parsed_url.path}"
    @super!
```

You'll notice in the default method, another method, `handle_404` is
referenced. This is also provided and looks like this:

```moon
handle_404: =>
  error "Failed to find route: #{@req.cmd_url}"
```

This will trigger a 500 error and a stack trace on every invalid request. If
you want to make a proper 404 page this is where you would do it.

Overriding the `handle_404` method instead of `default_route` allows us to
create a custom 404 page while still keeping the trailing slash removal code.

Here's a simple 404 handler that just prints the text `"Not Found!"`

```moon
class extends lapis.Application
  default_route: =>
    status: 404, layout: false, "Not Found!"
```

### Class Methods

#### `@find_action(action_name)`

Returns the function of the action that has the name specified by
`action_name`.

