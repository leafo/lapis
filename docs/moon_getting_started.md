title: Creating a Lapis Application with MoonScript
--
<div class="override_lang"></div>

# Creating a Lapis Application with MoonScript

## Creating a Basic Application

You can start a new MoonScript project in the current directory by running the
following command:

```bash
$ lapis new
```

This provides us with a default Nginx configuration, `nginx.conf`, and a
skeleton application, `app.moon`. The skeleton application looks like this:

```moon
-- app.moon
lapis = require "lapis"

class extends lapis.Application
  "/": =>
    "Welcome to Lapis #{require "lapis.version"}!"
```

This defines a regular Lua module that returns our application class. (Implicit
return in MoonScript states that the last statement in a block of code is the
return value.)

> Don't forget to compile the `.moon` files when changing and creating them.
> You can watch the current directory and compile automatically with `moonc
> -w`.

Try it out by starting the server:

```bash
lapis server
```

If you've compiled the `.moon` file then <http://localhost:8080> will display
the page.

The members of the application class make up the patterns that can be matched
by incoming requests. This is referred to as the route and the action, where
the route is the pattern and the action is the function that handles the
matching route.  In this example, the route `"/"` is matched to a function that
returns `"Hello World!"`

The return value of an action determines what is written as the response. In
the simplest form we can return a string in order to write a string.

> Learn more about routes and actions and the return value in the [Routes and
> Actions][2] guide.

## Lapis Applications

When we refer to a Lapis application we are talking about a class that extends
from `lapis.Application`. The properties of the application make up the routes
the application can serve and the actions it will perform.

If a property name is a string and begins with a `"/"` or the property is a
table then it defines a route. All other properties are methods of the
application.

### Request Parameters

Routes can contain special patterns that match parts of the URL and put them
into a request parameter.

Named parameters are a `:` followed by a name. They match all characters
excluding `/`.

```moon
class extends lapis.Application
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

> Learn more about where parameters come from in the [Request Object guide][3].

### The Action

The action is the function called in response to a route matching the path of a
request. Actions are written with the fat arrow, `=>`, so you might think that
`self` is an instance of application. It's actually an instance of `Request`, a
class that's used to represent the current request.

As we've already seen, the request holds all the parameters in `@params`.

We can the get the distinct parameters types using `@GET`, `@POST`, and
`@url_params`.

We can also access the instance of the application with `@app`, and the raw
request and response with `@req` and `@res`.

You should treat `@app` as read only because the instance is shared among many
requests.

> Learn more about the request object in the [Request Object guide][3].

### Named Routes

It's useful to give names to your routes so links to other pages can be
generated just by knowing the name of the page instead of hard-coding the
structure of the URL.

If the route of the action is a table with a single pair, then the key of that
table is the name and the value is the pattern. MoonScript gives us convenient
syntax for representing this:

```moon
class extends lapis.Application
  [index: "/"]: =>
    @url_for "user_profile", name: "leaf"

  [user_profile: "/user/:name"]: =>
    "Hello #{@params.name}, go home: #{@url_for "index"}"
```

We can generate the paths to various actions using `@url_for`. The first
argument is the name of the route, and the second optional argument is a table
of values to fill a parameterized route with.

### Before Filters

Sometimes you want a piece of code to run before every action. A good example
of this is setting up the user session. We can declare a before filter, or a
function that runs before every action, like so:

```moon
lapis = require "lapis"

class App extends lapis.Application
  @before_filter =>
    if @session.user
      @current_user = load_user @session.user

  "/": =>
    "current user is: #{@current_user}"
```

You are free to add as many as you like by calling `@before_filter` multiple
times. They will be run in the order they are registered.

If a before filter calls the `@write` method then the action will be cancelled.
For example we can cancel the action and redirect to another page if some
condition is not met:

```moon
lapis = require "lapis"

class App extends lapis.Application
  @before_filter =>
    unless user_meets_requirements!
      @write redirect_to: @url_for "login"

  "/": =>
    "Welcome to the page"
```

> `@write` is what handles the return value of an action, so the same things
> you can return in an action can be passed to `@write`

### Handling HTTP verbs

It's common to have a single action do different things depending on the HTTP
verb. Lapis comes with some helpers to make writing these actions simple.
`respond_to` takes a table indexed by HTTP verb with a value of the function to
perform when the action receives that verb.

```moon
lapis = require "lapis"
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
lapis = require "lapis"

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
  @include "applications.users"

  [index: "/"]: =>
    @html ->
      a href: @url_for("login"), "Log in"
```

In this example `applications/user.moon` is a module that returns the
sub-application. The `include` class method is used to load this application
into our root one. `include` copies all the routes of the other application,
leaving the original untouched.

Sub-applications are allowed to have before filters, and the before filters
will only apply to all actions enclosed by the application.

A sub-application supports special `path` and `name` class values:

* `path` -- The patterns of the routes copied are prefixed with `path`
* `name` -- The names of all the routes copied are prefixed with `name`

```moon
class UsersApplication extends lapis.Application
  @path: "/users"
  @name: "user_"

  -- etc...
```

`include` takes an optional second argument, a table of options. The options
can be used to provide or override the `path` and `name` values that might have
been set in the application.

For example, we might prefix `UsersApplication` like so:

```moon
class extends lapis.Application
  @include "applications.users", path: "/users", name: "user_"

  "/": =>
    @url_for("user_login") -- returns "/users/login"
```

### Class Methods

#### `@find_action(action_name)`

Returns the function of the action that has the name specified by
`action_name`.

[1]: http://moonscript.org/reference/#moonc
[2]: $root/reference/actions.html
[3]: $root/reference/actions.html#request-object
