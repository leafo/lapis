
# Lapis Guide

Lapis is a web framework written in MoonScript. It is designed to be used with
MoonScript but can also works fine with Lua. Lapis is interesting because it's
built on top of the Nginx distribution [OpenResty][0]. Your web application is
run directly inside of Nginx. Nginx's event loop lets you make asynchronous
HTTP requests, database queries and other requests using the modules provided
with OpenResty. Lua's coroutines allows you to write synchronous looking code
that is event driven behind the scenes.

Lapis is early in development but it comes with a url router, html templating
through a MoonScript DSL, CSRF and session support, a basic Postgres backed
active record system for working with models and a handful of other useful
functions needed for developing websites.

This guide hopes to serve as a tutorial and a reference.

## Basic Setup

Install OpenResty onto your system. If you're compiling manually it's
recommended to enable Postgres and Lua JIT. If you're using heroku then you can
use the Heroku OpenResy module along with the Lua build pack.

Next install Lapis using LuaRocks. You can find the rockspec [on MoonRocks][3]:

    ```bash
    $ luarocks install --server=http://rocks.moonscript.org/manifests/leafo lapis
    ```

## Creating An Application

### `lapis` command line tool

Lapis comes with a command line tool to help you create new projects and start
your server. To see what Lapis can do, run in your shell:


    ```bash
    $ lapis help
    ```

For now though, we'll just be creating a new project. Navigate to a clean
directory and run:

    ```bash
    $  lapis new

    ->	wrote	nginx.conf
    ->	wrote	mime.types
    ```

Lapis starts you off by writing some basic Nginx configuration. Because your
application runs directly in Nginx, this configuration is what routes requests
from Nginx to your Lua code.

Feel free to look at the generated config file (`nginx.conf` is the only
important file). Here's a brief overview of what it does:

 * Any requests inside `/static/` will serve files out of the directory
   `static` (You can create this directory now if you want)
 * A request to `/favicon.ico` is read from `static/favicon.ico`
 * All other requests will be served by `web.lua`. (We'll create this next)

When you start your server with Lapis, the `nginx.conf` file is actually
processed and templated variables are filled in based on the server's
environment. We'll talk about how to configure these things later on.

### Nginx Configuration

Let's take a look at the configration that `lapis new` has given us. Although
it's not necessary to look at this immediately, it's important to understand
when building more advanced applications or even just deploying your
application to production.

Here is the `nginx.conf` that has been generated:

    ```nginx
    worker_processes  ${{NUM_WORKERS}};
    error_log stderr notice;
    daemon off;
    env LAPIS_ENVIRONMENT;

    events {
        worker_connections 1024;
    }

    http {
        include mime.types;

        server {
            listen ${{PORT}};
            lua_code_cache off;

            location / {
                default_type text/html;
                set $_url "";
                content_by_lua_file "web.lua";
            }

            location /static/ {
                alias static/;
            }

            location /favicon.ico {
                alias static/favicon.ico;
            }
        }
    }
    ```


The first thing to notice is that this is not a normal Nginx configuration
file. You'll notice special `${{VARIABLE}}` syntax. When starting your server
with Lapis, these variables are replaced with their values pulled from the
active configuration.

The rest of the syntax is regular Nginx configuration syntax.

There are a couple interesting things here. `error_log stderr notice` and
`daemon off` lets our server run in the foreground, and print log text to the
console. This is great for development, but worth turning off in a production
environment.

`lua_code_cache off` is also another setting nice for development. It causes
all Lua modules to be reloaded on each request, so if we change files after
starting the server they will be picked up. Something you also want to turn off
in production for the best performance.

Our single location calls the directive `content_by_lua_file "web.lua"`. This
causes all requests of that location to run through `web.lua`, so let's make
that now.

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

We can now navigate to <http://localhost:8080/> to see our application.

## Lapis Applications

Let's start with the basic application from above:

    ```moon
    lapis = require "lapis"
    lapis.serve class extends lapis.Application
      "/": => "Hello World!"
    ```

### URL Parameters

Named parameters are a `:` followed by a name. They match all characters
excluding `/`.

    ```moon
    "/user/:name": => "Hello #{@params.name}"
    ```


If we were to go to the path "/user/leaf", `@params.name` would be set to
`"leaf"`.

`@params` holds all the parameters to the action. This is a concatenation of
the URL parameters, the GET parameters and the POST parameters.

A splat will match all characters and is represented with a `*`. Splats are not
named. The value of the splat is placed into `@params.splat`

    ```moon
    "/things/*": => "Rest of the url: #{@params.splat}"
    ```

### The Action

The action is the method that response to the request for the matched route. In
the above example it uses a fat arrow, `=>`, so you might think that `self` is
an instance of application. But it's not, it's actually an instance of
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

## HTML Generation

### HTML In Actions

If we want to generate HTML directly in our action we can use the `@html`
method:

    ```moon
    "/": =>
      @html ->
        h1 class: "header", "Hello"
        div class: "body", ->
          text "Welcome to my site!"
    ```

HTML templates are written directly as MoonScript code. This is a very powerful
feature (inspirted by [Erector](http://erector.rubyforge.org/)) that gives us
the ability to write templates with high composability and also all the
features of MoonScript. No need to learn any goofy templating syntax with
arbitrary restrictions.

The `@html` method overrides the environment of the function passed to it.
Functions that create HTML tags are generated on the fly as you call them. The
output of these functions is written into a buffer that is compiled in the end
and returned as the result of the action.

Here are some examples of the HTML generation:

    ```moon
    div!                -- <div></div>
    b "Hello World"     -- <b>Hello World</b>
    div "hi<br/>"       -- <div>hi&lt;br/&gt;</div>
    text "Hi!"          -- Hi!
    raw "<br/>"         -- <br/>

    element "table", width: "100%", ->  -- <table width="100%"></table>

    div class: "footer", "The Foot"     -- <div class="footer">The Foot</div>

    div ->                              -- <div>Hey</div>
      text "Hey"

    div class: "header", ->             -- <div class="header"><h2>My Site</h2><p>Welcome!</p></div>
      h2 "My Site"
      p "Welcome!"
    ```


### HTML Widgets

The preferred way to write HTML is through widgets. Widgets are classes who are
only concerned with outputting HTML. They use the same syntax as the `@html`
shown above helper for writing HTML.

When Lapis loads a widget automatically it does it by package name. For
example, if it was loading the widget for the name `"index"` it would try to
load the module `views.index`, and the result of that module should be the
widget.

This is what a widget looks like:

    ```moon
    -- views/index.moon
    import Widget from require "lapis.html"

    class Index extends Widget
      content: =>
        h1 class: "header", "Hello"
          div class: "body", ->
            text "Welcome to my site!"
    ```


> The name of the widget class is insignificant, but it's worth making one
> because some systems can auto-generate encapsulating HTML named after the
> class.

### Rendering A Widget From An Action

The `render` option key is used to render a widget. For example you can render
the `"index"` widget from our action by returning a table with render set to
the name of the widget:

    ```moon
    "/": =>
      render: "index"
    ```

If the action has a name, then we can set render to `true` to load the widget
with the same name as the action:

    ```moon
    [index: "/"]: =>
      render: true
    ```

### Passing Data To A Widget

Any `@` variables set in the action can be accessed in the widget. Additionally
any of the helper functions like `@url_for` are also accessible.

    ```moon
    -- web.moon
    [index: "/"]: =>
      @page_title = "Welcome To My Page"
      render: true

    -- views/index.moon
    import Widget from require "lapis.html"

    class Index extends Widget
      content: =>
        h1 class: "header", @page_title
          div class: "body", ->
            text "Welcome to my site!"
    ```

## Before Filters

Sometimes you want a piece of code to run before every action. A good example
of this is setting up the user session. We can declare a before filter, or a
function that runs before every action like so:

    ```moon
    class App extends lapis.Application
      @before_filter =>
        if @session.user
          @current_user = load_user @session.user

      "/": =>
        "current user is: #{@current_user}"
    ```

You are free to register as many as you like by calling `@before_filter`
multiple times. They will be run in the order they are registered.

## Handling HTTP verbs

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


## Exception Handling

Lapis comes with a set of exception handling routines for recovering from errors
and displaying something appropriate. We use the `capture_errors` helper to
capture any errors and run an error handler.

When we refer to exceptions we are talking about messages thrown explicitly by
the programmer. This doesn't include runtime errors. You should use `pcall` if
you want to capture runtime errors as you would normally do in Lua.

Lua doesn't have the concept of exceptions like most other languages. Instead
Lapis creates an exception handling system using coroutines. We must define the
scope in which we will capture errors. We do that using the `capture_errors`
helper. Then we can throw a raw error using `yield_error`.

    ```moon
    import capture_errors, yield_error from require "lapis.application"

    class App extends lapis.Application
      "/do_something": capture_errors =>
        yield_error "something bad happend"
        "Hello!"
    ```

What happens when there is an error? The action will stop executing at the
first error, and then the error handler is run. The default one will set an
array like table of errors to `@errors` and return `render: true`. In your view
you can then display the errors.

If you want to have a custom error handler you can invoke `capture_errors` with
a table: (note that `@errors` is set before the custom handler)

    ```moon
    class App extends lapis.Application
      "/do_something": capture_errors {
        on_error: =>
          log_errors @errors
          render: "my_error_page", status: 500

        =>
          if @params.bad_thing
            yield_error "something bad happend"
          render: true
      }
    ```

`capture_errors` when called with a table will use the first positional value
as the action.

### `assert_error`

It is idiomatic in Lua to return `nil` and an error message from a function
when it fails. For this reason the helper `assert_error` exists. If the first
argument is falsey (`nil` or `false`) then the second argument is thrown as an
error, otherwise the first argument is returned.

`assert_error` is very handy with database methods, which make use of this
idiom.

    ```moon
    import capture_errors, assert_error from require "lapis.application"

    class App extends lapis.Application
      "/": capture_errors =>
        user = assert_error User\find id: "leafo"
        "result: #{result}"
    ```


## Input validation

Lapis comes with a set of validators for working with external inputs. Here's a
quick example:

    ```moon
    import capture_errors from require "lapis.application"
    import assert_valid from require "lapis.validate"

    class App extends lapis.Application
      "/create_user": capture_errors =>

        assert_valid @params, {
          { "username", exists: true, min_length: 2, max_length: 25 }
          { "password", exists: true, min_length: 2 }
          { "password_repeat", equals: @params.password }
          { "email", exists: true, min_length: 3 }
          { "accept_terms", equals: "yes", "You must accept the Terms of Service" }
        }

        create_the_user @params
        render: true
    ```

`assert_valid` takes two arguments, a table to be validated, and a second array
table with a list of validations to perform. Each validation is the following format:

    { Validation_Key, [Error_Message], Validation_Function: Validation_Argument, ... }

`Validation_Key` is the key to fetch from the table being validated.

Any number of validation functions can be provided. If a validation function
takes multiple arguments, an array table can be passed

`Error_Message` is an optional second positional value. If provided it will be
used as the validation failure error message instead of the default generated
one. Because of how Lua tables work, it can also be provided after the
validation functions as demonstrated in the example above.

### Validation Functions

* `exists: true` -- check if the value exists and is not an empty string
* `file_exists: true` -- check if the value is a file upload
* `min_length: Min_Length` -- value must be at least `Min_Length` chars
* `max_length: Max_Length` -- value must be at most `Max_Length` chars
* `is_integer: true` -- value matches integer pattern
* `is_color: true` -- value matches CSS hex color (eg. `#1234AA`)
* `equals: String` -- value is equal to String
* `one_of: {A, B, C, ...}` -- value is equal to one of the elements in the array table


Custom validators can be added like so:

    ```moon
    import validate_functions, assert_valid from require "lapis.validate"

    validate_functions.integer_greater_than = (input, min) ->
      num = tonumber input
      num and num > min, "%s must be greater than #{min}"

    import capture_errors from require "lapis.application"

    class App extends lapis.Application
      "/": capture_errors =>
        assert_valid @params, {
          { "number", integer_greater_than: 100 }
        }
    ```

### Manual Validation

In addition to `assert_valid` there is one more useful validation function:

    ```moon
    import validate from require "lapis.validate"
    ```

* `validate(object, validation)` -- takes the same exact arguments as
  `assert_valid`, but returns the either errors or `nil` on failure instead of
  yielding the error.


[0]: http://openresty.org/
[1]: https://github.com/leafo/heroku-openresty
[2]: https://github.com/leafo/heroku-buildpack-lua
[3]: http://rocks.moonscript.org/modules/leafo/lapis
[4]: http://moonscript.org/reference/#moonc

