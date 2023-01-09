{
  title: "Creating a Lapis Application with MoonScript"
}
<div class="override_lang" data-lang="moonscript"></div>

# Creating a Lapis Application with MoonScript

## Creating a Basic Application

You can start a new MoonScript project in the current directory by running the
following command:

```bash
$ lapis new --moonscript
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
> -w` but be aware new files aren’t picked up, you have to restart `moonc`.

Try it out by starting the server:

```bash
lapis server
```

If you've compiled the `.moon` file then <http://localhost:8080> will display
the page.

## Lapis Applications

When we refer to a Lapis application we are talking about a class that extends
from `lapis.Application`. The properties of the application make up the routes
the application can serve and the actions it will perform.


Here's a slightly more complicated example to give you a feel of what they look
like:

```moon
lapis = require "lapis"

favorite_foods = {
  "pizza": "Wow pizza is the best! Definitely my favorite"
  "egg": "A classic breakfast, never leave home without"
  "ice cream": "Can't have a food list without a dessert"
}

class App extends lapis.Application
  [index: "/"]: =>
    -- Render HTML inline for simplicity
    @html ->
      h1 "My homepage"
      a href: @url_for("list_foods"), "Check out my favorite foods"

  [list_foods: "/foods"]: =>
    @html ->
      ul ->
        for food in pairs favorite_foods
          li ->
            a href: @url_for("food", name: food), food

  [food: "/food/:name"]: =>
    food_description = favorite_foods[@params.name]
    unless food_description
      return "Not found", status: 404

    @html ->
      h1 @params.name
      h2 "My thoughts on this food"
      p food_description
```

You can learn about each of the components used in this example on the
[Requests and Actions guide][2].

## MoonScript Tips

Lapis is a bi-language library. It works for either MoonScript or Lua. The rest
of this page will have information specific to the MoonScript interface.
It might be more helpful to check out the [Requests and Actions guide][2] first
to learn more about the basics before reading this section.

### Actions

The members of the application class make up the patterns that can be matched
by incoming requests. This is referred to as the route and the action, where
the route is the pattern and the action is the function that handles the
matching route:

```moon
lapis = require "lapis"

class App extends lapis.Application
  "/hello": => "Hello World!"
```

In this example, the route `"/hello"` is matched to a function that
returns `"Hello World!"`

The action is the function called in response to a route matching the path of a
request. Actions are written with the fat arrow, `=>`, because they all receive
a first argument from Lapis. You might think that `self` is an instance of
application. It's actually an instance of `Request`, a class that's used to
represent the current request.

We can also access the instance of the application with `@app`. You should
treat `@app` as read only because the instance is shared among many requests.

The members of the class that you want to be routes must start with `"/"`,
otherwise they are treated as regular methods of the application class.

### Sub-Applications

As your application becomes more complex it helps to break it apart into
multiple sub-applications. Lapis doesn't place any rules on how you divide your
application, instead it gives you tools to organize your own way.

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

In this example `applications/users.moon` is a module that returns the
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

[1]: http://moonscript.org/reference/#moonc
[2]: $root/reference/actions.html
