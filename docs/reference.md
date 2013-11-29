
# Lapis Guide

[Lapis](http://leafo.net/lapis/) is a web framework written in MoonScript. It is
designed to be used with MoonScript but can also works fine with Lua. Lapis is
interesting because it's built on top of the Nginx distribution [OpenResty][0].
Your web application is run directly inside of Nginx. Nginx's event loop lets
you make asynchronous HTTP requests, database queries and other requests using
the modules provided with OpenResty. Lua's coroutines allows you to write
synchronous looking code that is event driven behind the scenes.

Lapis is early in development but it comes with a URL router, HTML templating
through a MoonScript DSL, CSRF and session support, a basic PostgreSQL backed
active record system for working with models and a handful of other useful
functions needed for developing websites.

This guide hopes to serve as a tutorial and a reference.

## Basic Setup

Install OpenResty onto your system. If you're compiling manually it's
recommended to enable PostgreSQL and Lua JIT. If you're using Heroku then you
can use the Heroku OpenResy module along with the Lua build pack.

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

Lapis starts you off by writing some basic Nginx configuration. Your
application runs directly in Nginx and this configuration is what routes
requests from Nginx to your Lua code.

Feel free to look at the generated configuration file (`nginx.conf` is the only
important file). Here's a brief overview of what it does:

 * Any requests inside `/static/` will serve files out of the directory
   `static` (You can create this directory now if you want)
 * A request to `/favicon.ico` is read from `static/favicon.ico`
 * All other requests will be served by `web.lua`. (We'll create this next)

When you start your server with Lapis, the `nginx.conf` file is actually
processed and templated variables are filled in based on the server's
environment. We'll talk about how to configure these things later on.

### Nginx Configuration

Let's take a look at the configuration that `lapis new` has given us. Although
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
file. Special `${{VARIABLE}}` syntax is used by Lapis to inject environment
settings before starting the server.

There are a couple interesting things provided by the default configuration.
`error_log stderr notice` and `daemon off` lets our server run in the
foreground, and print log text to the console. This is great for development,
but worth turning off in a production environment.

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

[Named routes](#named_routes) are constructed using a table as a property name.

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

If the client application sends HTTP header content-type set to 'application/json' the body will be decoded from JSON into a lua table and inserted into @params.

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
  [login: "/login"] => do_login!
  [logout: "/logout"] => do_logout!
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
  path: "/users"
  name: "user_"

  -- etc...
```

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
feature (inspired by [Erector](http://erector.rubyforge.org/)) that gives us
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

div class: "header", ->             -- <div class="header"><h2>My Site</h2>
                                    --    <p>Welcome!</p></div>
  h2 "My Site"
  p "Welcome!"
```


### HTML Widgets

The preferred way to write HTML is through widgets. Widgets are classes who are
only concerned with outputting HTML. They use the same syntax as the `@html`
helper shown above for writing HTML.

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
```

```moon
-- views/index.moon
import Widget from require "lapis.html"

class Index extends Widget
  content: =>
    h1 class: "header", @page_title
    div class: "body", ->
      text "Welcome to my site!"
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
    user = assert_error Users\find id: "leafo"
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


## Configuration and Environments

Lapis is designed to run your server in different configurations called
environments. For example you might have a development configuration with a
local database URL, code caching disabled, and a single worker. Then you might
have a production configuration with remote database URL, code caching enabled,
and 8 workers.

The `lapis` command line tool takes a second argument when starting the server:

```bash
$ lapis server [environment]
```

By default the environment is `development`. The environment name only affects
what configuration is loaded. This has absolutely no effect if you don't have any
configurations, so let's create some.


### Creating Configurations

Whenever Lapis starts the server it attempts to load the module `"config"`. If
it can't be found it is silently ignored. The `"config"` module is where we
define out configurations. It's a standard Lua/MoonScript file, so let's create
it.

```moon
-- config.moon
import config from require "lapis.config"

config "development", ->
  port 8080


config "production", ->
  port 80
  num_workers 4
  lua_code_cache "off"

```

We use the configuration helpers provided in `"lapis.config"` to create our
configurations. This defines a domain specific language for setting variables.
In the example above we define two configurations, and set the ports for each
of them.

A configuration is just a plain table. Use the special builder syntax above to
construct the configuration tables.

### Configurations and Nginx

The values in the configuration are used when compiling `nginx.conf`.
Interpolated Nginx configuration variables are case insensitive. They are
typically written in all capitals because the shell's environment is checked
for a value before the configuration is checked.

For example, here's a chunk of an Lapis Nginx configuration:

```nginx
events {
  worker_connections ${{WORKER_CONNECTIONS}};
}
```

When this is compiled, first the environment variable
`LAPIS_WORKER_CONNECTIONS` is checked. If it doesn't have a value then the
configuration of the current environment is checked for `worker_connections`.

### Accessing Configuration From Application

The configuration is also made available in the application. We can get access
to the configuration table like so:

```moon
config = require("lapis.confg").get!
print config.port -- shows the current port
```

The name of the environment is stored in `_name`.

```moon
print config._name -- development, production, etc...
```

### Configuration Builder Syntax

Here's an example of the configuration DSL (domain specific language) and the
table it generates:

```moon
some_function = -> steak "medium_well"

config "development", ->
  hello "world"

  if 20 > 4
    color "blue"
  else
    color "green"

  custom_settings ->
    age 10
    enabled true

  -- tables are merged
  extra ->
    name "leaf"
    mood: "happy"

  extra ->
    name "beef"
    shoe_size: 12

    include some_function


  include some_function

  -- a normal table can be passed instead of a function
  some_list {
    1,2,3,4
  }

  -- use set to assign names that are unavailable
  set "include", "hello"
```

```moon
{
  hello: "world"
  color: "blue"

  custom_settings: {
    age: 10
    enabled: true
  }

  extra: {
    name: "beef"
    mood: "happy"
    shoe_size: 12
    steak: "medium_well"
  }

  steak: "medium_well"

  some_list: { 1,2,3,4 }

  include: "hello"
}
```

## Database Access

Lapis comes with a set of classes and functions for working with
[PostgreSQL][5]. In the future other databases might be directly supported.

### Configuring The Upstream & Location

Every query is performed asynchronously by sending an internal sub-request to a
special location defined in our Nginx configuration. This location communicates
with an upstream, which automatically manages a pool of PostgreSQL database
connections. This is handled by the
[`ngx_postgres`](https://github.com/FRiCKLE/ngx_postgres) module that is
bundled with OpenResty.

First we'll add the upstream to our `nginx.conf`, it's how we specify the
host and authentication of the database. Place the following in the `http`
block:

```nginx
upstream database {
  postgres_server ${{pg POSTGRESQL_URL}};
}
```

In this example the `pg` filter is applied to our `POSTGRESQL_URL`
configuration variable. Let's go ahead and add a value to our `config.moon`

```moon
config "development", ->
  postgresql_url "postgres://postgres:@127.0.0.1/my_database"
```

The `pg` filter will convert the PostgreSQL URL to the right format for the
Nginx PostgreSQL module.

Lastly, we add the location. Place the following in your `server` block:

```nginx
location = /query {
  internal;
  postgres_pass database;
  postgres_query $echo_request_body;
}
```

> The location must be named `/query` by default. And `postgres_pass` must
> match the name of the upstream. In this example we use `database`.



The `internal` setting is very important. This allows the location to only be
used within the context of a sub-request.

You're now ready to start making queries.

### Making A Query

There are two ways to make queries. The first way is to use the raw query
interface, a collection of functions to help you write SQL.

The second way is to use the `Model` class, a wrapper around a Lua table that
helps you synchronize it with a row in a database table.

Here's a base example using the raw query interface:

```moon
db = require "lapis.db"

lapis.serve class extends lapis.Application
  "/": =>
    res = db.query "select * from my_table where id = ?", 10
    "ok!"
```

By default all queries will log to the Nginx log. You'll be able to see each
query as it happens.

## Query Interface

```moon
db = require "lapis.db"
```

### Functions

The `db` module provides the following functions:

#### `query(query, params...)`

Performs a raw query. Returns the result set if successful, returns `nil` if
failed.

The first argument is the query to perform. If the query contains any `?`s then
they are replaced in the order they appear with the remaining arguments. The
remaining arguments are escaped with `escape_literal` before being
interpolated, making SQL injection impossible.

```moon
res = db.query "SELECT * FROM hello"
res = db.query "UPDATE things SET color = ?", "blue"
res = db.query "INSERT INTO cats (age, name, alive) VALUES (?, ?, ?)", 25, "dogman", true
```

```sql
SELECT * FROM hello
UPDATE things SET color = 'blue'
INSERT INTO cats (age, name, alive) VALUES (25, 'dogman', TRUE)
```

> Due to a limitation in the PostgreSQL Nginx extension, it is not possible to
> get the error message if the query has failed. You can however see the error
> in the logs.

#### `select(query, params...)`

The same as `query` except it appends `"SELECT"` to the front of the query.

```moon
res = db.select "* from hello where active = ?", db.FALSE
```

```sql
SELECT * from hello where active = FALSE
```

#### `insert(table, values, returning...)`

Inserts a row into `table`. `values` is a Lua table of column names and values.

```moon
db.insert "my_table", {
  age: 10
  name: "Hello World"
}
```

```sql
INSERT INTO "my_table" ("age", "name") VALUES (10, 'Hello World')
```

A list of column names to be returned can be given after the value table:

```moon
res = db.insert "some_other_table", {
  name: "Hello World"
}, "id"
```

```sql
INSERT INTO "some_other_table" ("name") VALUES ('Hello World') RETURNING "id"
```

#### `update(table, values, conditions, params...)`

Updates `table` with `values` on all rows that match `conditions`.

```moon
db.update "the_table", {
  name: "Dogbert 2.0"
  active: true
}, {
  id: 100
}
```

```sql
UPDATE "the_table" SET "name" = 'Dogbert 2.0', "active" = TRUE WHERE "id" = 100
```

`conditions` can also be a string, and `params` will be interpolated into it:

```moon
db.update "the_table", {
  count: db.raw"count + 1"
}, "count < ?", 10
```

```sql
UPDATE "the_table" SET "count" = count + 1 WHERE count < 10
```

#### `delete(table, conditions, params...)`

Deletes rows from `table` that match `conditions`.

```moon
db.delete "cats", name: "Roo"
```

```sql
DELETE FROM "cats" WHERE "name" = 'Roo'
```

`conditions` can also be a string

```moon
db.delete "cats", "name = ?", "Gato"
```

```sql
DELETE FROM "cats" WHERE name = 'Gato'
```

#### `raw(str)`

Returns a special value that will be inserted verbatim into query without being
escaped:

```moon
db.update "the_table", {
  count: db.raw"count + 1"
}

db.select "* from another_table where x = ?", db.raw"now()"
```

```moon
UPDATE "the_table" SET "count" = count + 1
SELECT * from another_table where x = now()
```

#### `escape_literal(value)`

Escapes a value for use in a query. A value is any type that can be stored in a
column. Numbers, strings, and booleans will be escaped accordingly.

```moon
escaped = db.escape_literal value
res = db.query "select * from hello where id = #{escaped}"
```

`escape_literal` is not appropriate for escaping column or table names. See
`escape_identifier`.

#### `escape_identifier(str)`

Escapes a string for use in a query as an identifier. An identifier is a column
or table name.

```moon
table_name = db.escape_literal "table"
res = db.query "select * from #{table_name}"
```

`escape_identifier` is not appropriate for escaping values. See
`escape_literal` for escaping values.

### Constants

The following constants are also available:

 * `NULL` -- represents `NULL` in SQL
 * `TRUE` -- represents `TRUE` in SQL
 * `FALSE` -- represents `FALSE` in SQL

## Models

Lapis provides a `Model` baseclass for making tables that can be synchronized
with a database row. The class is used to represent a single table, an instance
of the class is used to represent a single row of that table.

The most primitive model is a blank model:

```moon
import Model from require "lapis.db.model"

class Users extends Model
```

The name of the class is used to determine the name of the table. In this case
the class name `Users` represents the table `users`. A class name of
`HelloWorlds` would result in the table name `hello_worlds`. It is customary to
make the class name plural.

If you want to use a different table name you can overwrite the `@table_name`
class method:

```moon
class Users extends Model
  @table_name: => "active_users"
```

### Primary Keys

By default all models have the primary key "id". This can be changed by setting
the `@primary_key` class variable.

```moon
class Users extends Model
  @primary_key: "login"
```

If there are multiple primary keys then a array table can be used:

```moon
class Followings extends Model
  @primary_key: { "user_id", "followed_user_id" }
```

### Finding A Row

For the following examples assume we have the following models:

```moon
import Model from require "lapis.db.model"

class Users extends Model

class Tags extends Model
  @primary_key: {"user_id", "tag"}
```

When you want to find a single row the `find` class method is used. In the
first form it takes a variable number of values, one for each primary key in
the order the primary keys are specified:


```moon
user = Users\find 23232
tag = Tags\find 1234, "programmer"
```

```sql
SELECT * from "users" where "id" = 23232 limit 1
SELECT * from "tags" where "user_id" = 1234 and "tag" = 'programmer' limit 1
```

`find` returns an instance of the model. In the case of the user, if there was a
`name` column, then we could access the users name with `user.name`.

We can also pass a table as an argument to `find`. The table will be converted to a `WHERE` clause in the query:

```moon
user = Users\find email: "person@example.com"
```

```sql
SELECT * from "users" where "email" = 'person@example.com' limit 1
```

### Finding Many Rows

When searching for multiple rows the `select` class method is used. It works
similarly to the `select` function from the raw query interface except you
specify the part of the query after the list of columns to select.


```moon
tags = Tags\select "where tag = ?", "merchant"
```

```sql
SELECT * from "tags" where tag = 'merchant'
```

Instead of a single instance, an array table of instances is returned.

If you want to restrict what columns are selected you can pass in a table as
the last argument with the `fields` key set:

```moon
tags = Tags\select "where tag = ?", "merchant", fields: "created_at as c"
```

```sql
SELECT created_at as c from "tags" where tag = 'merchant'
```

Alternatively if you want to find many rows by their primary key you can use
the `find_all` method. It takes an array table of primary keys. This method
only works on tables that have singular primary keys.

```moon
users = Users\find_all { 1,2,3,4,5 }
```

```sql
SELECT * from "users" where "id" in (1, 2, 3, 4, 5)
```

### Inserting Rows

The `create` class method is used to create new rows. It takes a table of
column values to create the row with. It returns an instance of the model. The
create query fetches the values of the primary keys and sets them on the
instance using the PostgreSQL `RETURN` statement. This is useful for getting
the value of an auto-incrementing key from the insert statement.

```moon
user = Users\create {
  login: "superuser"
  password: "1234"
}
```

```sql
INSERT INTO "users" ("password", "login") VALUES ('1234', 'superuser') RETURNING "id"
```

### Updating A Row

Instances of models have the `update` method for updating the row. The values
of the primary keys are used to uniquely identify the row for updating.

The first form of update takes variable arguments. A list of strings that
represent column names to be updated. The values of the columns are taken from
the current values in the instance.

```moon
user = Users\find 1
user.login = "uberuser"
user.email = "admin@example.com"

user\update "login", "email"
```

```sql
UPDATE "users" SET "login" = 'uberuser', "email" = 'admin@example.com' WHERE "id" = 1
```

Alternatively we can pass a table as the first argument of `update`. The keys
of the table are the column names, and the values are the values to update the
columns too. The instance is also updated. We can rewrite the above example as:

```moon
user = Users\find 1
user\update {
  login: "uberuser"
  email: "admin@example.com"
}
```

```sql
UPDATE "users" SET "login" = 'uberuser', "email" = 'admin@example.com' WHERE "id" = 1
```

> The table argument can also take positional values, which are treated the
> same as the variable argument form.

### Deleting A Row

Just call `delete` on the instance:

```moon
user = Users\find 1
user\delete!
```

```sql
DELETE FROM "users" WHERE "id" = 1
```

### Timestamps

Because it's common to store creation and update time models have
support for managing these columns automatically.

When creating your table make sure your table has the following columns:


```sql
CREATE TABLE ... (
  ...
  "created_at" timestamp without time zone NOT NULL,
  "updated_at" timestamp without time zone NOT NULL
)
```

Then define your model with the `@timestamp` class variable set to true:

```moon
class Users extends Model
  @timestamp: true
```

Whenever `create` and `update` are called the appropriate timestamp column will
also be set.


### Preloading Associations

A common pitfall when using active record type systems is triggering many
queries inside of a loop. In order to avoid situations like this you should
load data for as many objects as possible in a single query before looping over
the data.

We'll need some models to demonstrate: (The columns are annotated in a comment
above the model).

```moon
import Model from require "lapis.db.model"

-- columns: id, name
class Users extends Model

-- columns: id, user_id, text_content
class Posts extends Model
```

Given all the posts, we want to find the user for each post. We use the
`include_in` class method to include instances of that model in the array of
models instances passed to it.


```moon
posts = Posts\select! -- this gets all the posts

Users\include_in posts, "user_id"

print posts[1].user.name -- print the fetched data
```

```sql
SELECT * from "users" where "id" in (1,2,3,4,5,6)
```

Each post instance is mutated to have a `user` property assigned to it with an
instance of the `Users` model. The first argument of `include_in` is the array
table of model instances. The second argument is the column name of the foreign
key found in the array of model instances that maps to the primary key of the
class calling the `include_in`.

The name of the inserted property is derived form the name of the foreign key.
In this case, `user` was derived from the foreign key `user_id`. If we want to
manually specify the name we can do something like this:


```moon
Users\include_in posts, "user_id", as: "author"
```

Now all the posts will contain a property named `author` with an instance of
the `Users` model.

Sometimes the relationship is flipped. Instead of the list of model instances
having the foreign key column, the model we want to include might have it. This
is common in one-to-one relationships.

Here's another set of example models:

```moon
import Model from require "lapis.db.model"

-- columns: id, name
class Users extends Model

-- columns: user_id, twitter_account, facebook_username
class UserData extends Model
```

Now let's say we have a collection of users and we want to fetch the associated
user data:

```moon
users = Users\select!
UserData\include_in users, "user_id", flip: true

print users[1].user_data.twitter_account
```

```sql
SELECT * from "user_data" where "user_id" in (1,2,3,4,5,6)
```

In this example we set the `flip` option to true in the `include_in` method.
This causes the search to happen against our foreign key, and the ids to be
pulled from the `id` of the array of model instances.

Additionally, the derived property name that is injected into the model
instances is created from the name of the included table. In the example above
the `user_data` property contains the included model instances. (Had it been
plural the table name would have been made singular)

### Constraints

Often before we insert or update a row we want to check that some conditions
are met. In Lapis these are called constraints. For example let's say we have a
user model and users are not allowed to have the name "admin".

We might define it like this:


```moon
import Model from require "lapis.db.models"

class Users extends Model
  @constraints: {
    name: (value) =>
      if value\lower! == "admin"
        "User can not be named admin"
  }


assert Users\create {
  name: "Admin"
}
```

The `@constraints` class variable is a table that maps column name to a
function that should check if the constraint is broken. If anything truthy is
returned from the function then the update/insert fails, and that is returned
as the error message.

In the example above, the call to `assert` will fail with the error `"User can
not be named admin"`.

The constraint check function is passed 4 arguments. The model class, the value
of the column being checked, the name of the column being checked, and lastly
the object being checked. On insertion the object is the table passed to the
create method. On update the object is the instance of the model.

## Database Schemas

Lapis comes with a collection of tools for creating your database schema inside
of the `lapis.db.schema` module.

### Creating And Dropping Tables

#### `create_table(table_name, { table_declarations... })`

The first argument to `create_table` is the name of the table and the second
argument is an array table that describes the table.

```moon
db = require "lapis.nginx.postgres"
schema = require "lapis.db.schema"

import create_table, types from schema

create_table "users", {
  {"id", types.serial}
  {"username", types.varchar}

  "PRIMARY KEY (id)"
}
```

This will generate the following SQL:

```sql
CREATE TABLE IF NOT EXISTS "users" (
  "id" serial NOT NULL,
  "username" character varying(255) NOT NULL,
  PRIMARY KEY (id)
);
```

The items in the second argument to `create_table` can either be a table, or a
string. When the value is a table it is treated as a column/type tuple:

    { column_name, column_type }

They are both plain strings. The column name will be escaped automatically.
The column type will be inserted verbatim after it is passed through
`tostring`. `schema.types` has a collection of common types that can be used.
For example, `schema.types.varchar` is evaluates to `character varying(255) NOT
NULL`. See more about types below.

If the value to the second argument is a string then it is inserted directly
into the `CREATE TABLE` statement, that's how we create the primary key above.

#### `drop_table(table_name)`

Drops a table.

```moon
import drop_table from schema

drop_table "users"
```

```sql
DROP TABLE IF EXISTS "users";
```

### Indexes

#### `create_index(table_name, col1, col2..., [options])`

`create_index` is used to add new indexes to a table. The first argument is a
table, the rest of the arguments are the ordered columns that make up the
index. Optionally the last argument can be a Lua table of options.

There are two options `unique: BOOL`, `where: clause_string`.

`create_index` will also check if the index exists before attempting to create
it. If the index exists then nothing will happen.

Here are some example indexes:

```moon
import create_index from schema

create_index "users", "created_at"
create_index "users", "username", unique: true

create_index "posts", "category", "title"
create_index "uploads", "name", where: "not deleted"
```

This will generate the following SQL:

```sql
CREATE INDEX ON "users" (created_at);
CREATE UNIQUE INDEX ON "users" (username);
CREATE INDEX ON "posts" (category, title);
CREATE INDEX ON "uploads" (name) WHERE not deleted;
```

#### `drop_index(table_name, col1, col2...)`

Drops an index from a table. It calculates the name of the index from the table
name and columns. This is the same as the default index name generated by PostgreSQL.

```moon
import drop_index from schema

drop_index "users", "created_at"
drop_index "posts", "title", "published"
```

This will generate the following SQL:

```sql
DROP INDEX IF EXISTS "users_created_at_idx"
DROP INDEX IF EXISTS "posts_title_published_idx"
```

### Altering Tables

#### `add_column(table_name, column_name, column_type)`

Adds a column to a table.

```moon
import add_column, types from schema

add_column "users", "age", types.integer
```

Generates the SQL:

```sql
ALTER TABLE "users" ADD COLUMN "age" integer NOT NULL DEFAULT 0
```

#### `drop_column(table_name, column_name)`

Removes a column from a table.

```moon
import drop_column from schema

drop_column "users", "age"
```

Generates the SQL:

```sql
ALTER TABLE "users" DROP COLUMN "age"
```

#### `rename_column(table_name, old_name, new_name)`

Changes the name of a column.

```moon
import rename_column from schema

rename_column "users", "age", "lifespan"
```

Generates the SQL:

```sql
ALTER TABLE "users" RENAME COLUMN "age" TO "lifespan"
```

#### `rename_table(old_name, new_name)`

Changes the name of a table.

```moon
import rename_table from schema

rename_table "users", "members"
```

Generates the SQL:

```sql
ALTER TABLE "users" RENAME TO "members"
```

### Column Types

All of the column type generators are stored in `schema.types`. All the types
are special objects that can either be turned into a type declaration string
with `tostring`, or called like a function to be customized.

Here are all the default values:

```moon
import types from require "lapis.db.schema"

types.boolean       --> boolean NOT NULL DEFAULT FALSE
types.date          --> date NOT NULL
types.foreign_key   --> integer NOT NULL
types.integer       --> integer NOT NULL DEFAULT 0
types.numeric       --> numeric NOT NULL DEFAULT 0
types.serial        --> serial NOT NULL
types.text          --> text NOT NULL
types.time          --> timestamp without time zone NOT NULL
types.varchar       --> character varying(255) NOT NULL
```

You'll notice everything is `NOT NULL` by default, and the numeric types have
defaults of 0 and boolean false.

When a type is called like a function it takes one argument, a table of
options. The options include:

* `default: value` -- sets default value
* `null: boolean` -- determines if the column is `NOT NULL`
* `unique: boolean` -- determines if the column has a unique index
* `primary_key: boolean` -- determines if the column is the primary key

Here are some examples:

```moon
types.integer default: 1, null: true  --> integer DEFAULT 1
types.integer primary_key: true       --> integer NOT NULL DEFAULT 0 PRIMARY KEY
types.text null: true                 --> text
types.varchar primary_key: true       --> character varying(255) NOT NULL PRIMARY KEY
```

## Database Migrations

Because requirements typically change over the lifespan of a web application
it's useful to have a system to make incremental schema changes to the
database.

Lapis migrations work by storing a table of all the migrations that have run.
All migrations must have a name. Migrations typically are given a name of the
current Unix timestamp.

When migrations are run, the migration list is filtered down to those that have
not been run yet by checking the migrations table. The migrations to be run are
then sorted by their name in ascending order.

A migration itself is just a normal function that is called. It is expected to
call the schema functions described above (but it doesn't have to).

### Creating The Migration Table

Before running any migrations you must create the migration table. Do the following:

```moon
migrations = require "lapis.db.migrations"
migrations.create_migrations_table!
```

It will execute the following SQL:

```sql
CREATE TABLE IF NOT EXISTS "lapis_migrations" (
  "name" character varying(255) NOT NULL,
  PRIMARY KEY(name)
);
```

### Running Migrations

When organizing migrations it's best to create a module that returns the table
of our migrations:

```moon
-- migrations.moon
import types from require "lapis.db.schema"

{
  -- add deleted column
  [1366269069]: =>
    add_column "users", "deleted", types.boolean
    add_index "users", "deleted"
}
```

Now we can run migrations like so:

```moon
import run_migrations from require "lapis.db.migrations"
run_migrations require "migrations"
```

If you look in your console after running migrations you'll be able to see what
migrations have been run and their associated SQL.

## Request Object

As we've already seen the request object contains instance variables for all of the request parameters in `@params`. There are a few other properties as well.

* `@req` -- raw request table (generated from `ngx` state)
* `@res` -- raw response table (used to update `ngx` state)
* `@app` -- the instance of the application
* `@cookies` -- the table of cookies, can be assigned to set new cookies. Only
  supports strings as values
* `@session` -- signed session table. Can store values of any
  type that can be JSON encoded. Is backed by cookies
* `@options` -- set of options that controls how the request is rendered to nginx
* `@buffer` -- the output buffer

### @req

The raw request table `@req` wraps some of the ngx functions. Here is a list of utility functions available

 * `@req.headers` -- Request headers table 
 * `@req.parsed_url` -- Request parsed url.. A table with scheme, path, host, port and query.
 * `@req.params_post` -- Request POST parameters table
 * `@req.params_get` -- Request GET parameters table


When an action is executed the `write` method (described below) is called with
the return values.

### Request Options

Whenever a table is written, the key/value pairs (when the key is a string) are
copied into `@options`. For example, in this action the `render` and `status`
properties are copied.

```moon
"/": => render: "error", status: 404
```

After the action is finished, the options help determine what is sent to the
browser.

Here is the list of options that can be written

* `status` -- sets HTTP status code (eg 200, 404, 500, ...)
* `render` -- causes a view to be rendered with the request. If the value is
  `true` then the name of the route is used as the view name. Otherwise the value
  must be a string or a view class.
* `content_type` -- sets the `Content-type` header
* `json` -- causes the request to return the json encoded value of the
  property. The content type is set to `application/json` as well.
* `layout` -- changes the layout from the default defined by the application
* `redirect_to` -- sets status to 302 and sets `Location` header to value.
  Supports both relative and absolute URLs


### Cookies

The `@cookies` table in the request lets you read and write cookies. If you try
to iterate over the table to print the cookies you might notice it's empty:

```moon
"/": =>
  for k,v in pairs(@cookies)
    print k,v
```

The existing cookies are stored in the `__index` of the metatable. This is done
so we can when tell what cookies have been assigned to during the action
because they will be directly in the `@cookies` table.

Thus, to set a cookie we just need to assign into the `@cookies` table:

```moon
"/": =>
  @cookies.foo = "bar"
```

### Session

The `@session` is a more advanced way to persist data over requests. The
content of the session is serialized to JSON and stored in store in a specially
named cookie. The serialized cookie is also signed with you application secret
so it can't be tampered with. Because it's serialized with JSON you can store
nested tables and other primitive values.

The session can be set and read the same way as cookies:

```moon
"/": =>
  unless @session.current_user
    @session.current_user = "leaf"
```

### Methods

####  `write(things...)`

Writes all of the arguments. A different actions is done depending on the type
of each argument.

* `string` -- String is appended to output buffer
* `function` (or callable table) -- Function is called with the output buffer,
  result is recursively passed to `write`
* `table` -- key/value pairs are assigned into `@options`, all other values are
  recursively passed to `write`


#### `url_for(name_or_obj, params)`

Generates a URL for `name_or_obj`.

If `name_or_obj` is a string, then the route of that name is looked up and
filled using the values in params.

For example:

```moon
[user_data: "/data/:user_id/:data_field"] =>

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

```moon
class Users extends Model
  url_key: (route_name) => @id
```


#### `build_url(path, [options])`

Builds an absolute URL for the path. The current request's URI is used to build
the URL.

For example, if we are running our server on `localhost:8080`:

```moon
@build_url! --> http://localhost:8080
@build_url "hello" --> http://localhost:8080/hello

@build_url "world", host: "leafo.net", port: 2000 --> http://leafo.net:2000/world
```

## Utilities

### Methods

Utility functions are found in:

```moon
util = require "lapis.util"
```

####  `unescape(str)`

URL unescapes string

####  `escape(str)`

URL escapes string

####  `escape_pattern(str)`

Escapes string for use in Lua pattern

####  `parse_query_string(str)`

Parses query string into a table

####  `encode_query_string(tbl)`

Converts a key,value table into a query string

####  `underscore(str)`

Converst CamelCase to camel_case.

####  `slugify(str)`

Converts a string to a slug suitable for a URL. Removes all whitespace and
symbols and replaces them with `-`.

####  `uniquify(tbl)`

Returns a new table from `tbl` where there are no duplicate values.

####  `trim(str)

Trims the whitespace off of both sides of a string.

####  `trim_all(tbl)`

Trims the whitespace off of all values in a table (suitable for hash and array
tables).

####  `trim_filter(tbl)`

Trims the whitespace off of all values in a table. The entry is removed from
the table if the result is an empty string.

####  `to_json(obj)`

Converts `obj` to JSON. Will strip recursion and things that can not be encoded.

####  `from_json(str)`

Convers JSON to table, using lua cjson.

### Encoding Methods

Encoding functions are found in:

```moon
encoding = require "lapis.util.encoding"
```

#### `encode_base64(str)`

Base64 encodes a string.

#### `decode_base64(str)`

Base64 decodes a string.

#### `hmac_sha1(secret, str)`

Calculates the hmac-sha1 digest of `str` using `secret`. Returns a binary
string.

#### `encode_with_secret(object, secret)`

Encodes a Lua object and generates a signature for it. Returns a single string
that contains the encoded object and signature.

If secret is not provided the session secret is used.

#### `deocde_with_secret(msg_and_sig, secret)`

Decodes a string created by `encode_with_secret`. The decoded object is only
returned if the signature is correct. Otherwise returns `nil` and an error
message. The secret must match what was used with `encode_with_secret`.
Defaults to the session secret.

### CSRF Protection

CSRF protection provides a way to prevent fraudulent requests that originate
from other sites that are not your application. The common approach is to
generate a special token when the user lands on your page, then resubmit that
token on a subsequent POST request.

In Lapis the token is a cryptographically signed message that the server can
verify the authenticity of.

Before using any of the cryptographic functions it's important to set your
application's secret. This is a string that only the application knows about.
If you application is open source it's worthwhile to not commit this secret.

```moon
with require "lapis.session"
  .set_secret "this is my secret string 123456"
```

Now that you have the secret configured, we might create a CSRF protected form like so:


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

> If you're using CSRF protected in a lot of actions then it might be helpful
> to create a before filter that generates the token automatically.

The following functions are part of the CSRF module:

```moon
csrf = require "lapis.csrf"
```

####  `generate_token(req, key=nil, expires=os.time! + 28800)`

Generates a new CSRF token using the session secret. `key` is an optional piece
of data you can associate with the request. The token will expire in 8 hours by
default.

####  `validate_token(req, key)`

Valides the CSRF token located in `req.params.csrf_token`. If the token has a
key it will be validated against `key`. Returns `true` if it's valid, or `nil`
and an error message if it's invalid.

####  `assert_token(...)`

First calls `validate_token` with same arguments, then calls `assert_error` if
validation fails.


### Making HTTP Requests

Lapis comes with a built in module for making asynchronous HTTP requests. The
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
> `$_url` variable is used to used to store the target URL.

Now we can use the `lapis.nginx.http` module. There are two methods. `request`
and `simple`. `request` implements the Lua Socket HTTP request API (complete
with LTN12).

`simple` is a simplified API with no LTN12:

```moon
http = require "lapis.nginx.http"

class extends lapis.Application
  "/": =>
    -- a simple GET request
    body, status_code, headers = http\simple "http://leafo.net"

    -- a post request, data table is form encoded and content-type is set to
    -- application/x-www-form-urlencoded
    http\simple "http://leafo.net/", {
      name: "leafo"
    }

    -- manual invocation of the above request
    http\simple {
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

#### `simple(req, body)`

Performs an HTTP request using the internal `/proxy` location.

Returns 3 values, the string result of the request, http status code, and a
table of headers.

If there is only one argument and it is a string then that argument is treated
as a URL for a GET request.

If there is a second argument it is set as the body of a POST request. If
the body is a table it is encoded with `encode_query_string` and the
`Content-type` header is set to `application/x-www-form-urlencoded`

If the first argument is a table then it is used manually set request
parameters. I takes the following keys:

 * `url` -- the URL to request
 * `method` -- `"GET"`, `"POST"`, `"PUT"`, etc...
 * `body` -- string or table which is encoded
 * `headers` -- a table of request headers to set


#### `request(url_or_table, body)`

Implements a subset of [Lua Socket's
`http.request`](http://w3.impa.br/~diego/software/luasocket/http.html#request).

Does not support `proxy`, `create`, `step`, or `redirect`.


## Lapis Console

[Lapis Console][6] is a separate project that adds an interactive console to
your web application. Because Lapis runs inside of the Nginx loop, it's not
trivial to make a standard terminal based console that behaves the same way as
the web application. So a console that runs inside of your browser was created,
letting you reliably execute code in the same way as your web application when
debugging.

![Lapis Console Screenshot](http://leafo.net/dump/lapis_console.png "Screenshot of the Lapis Console exploring an object.")

Install through LuaRocks:

```bash
$ luarocks install --server=http://rocks.moonscript.org/manifests/leafo lapis_console
```

### Creating A Console

#### `console.make([opts])`

Lapis console provides an action that you can insert into your application to a
route of your choosing:

```moon
lapis = require "lapis"
console = require "lapis.console"

class extends lapis.Application
  "/console": console.make!
```

Now just head to to the `/console` location in your browser to use it. By
default the action that is created will only run in the `"development"`
environment.

You can set the `env` option in the first argument to `"all"` to enable in
every environment, or you can name an environment.

> Be careful about allowing access to the console, a malicious individual could
> destroy your application and compromise your system if given access.


### Tips

The console lets your write and execute a MoonScript program. Multiple lines
are supported.

The `print` function has been replaced in the console to print to the debug
output. You can print any type of object and the console will pretty print it.
Tables can be opened up and other types are color coded.

Any queries that execute during the script are logged to a special portion on
the bottom of the output.

`@` is equal to the value of the request that is initiating the console. You
can use this if you are testing a method that needs a request object.


## License (MIT)

    Copyright (C) 2013 by Leaf Corcoran

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.

<div class="footer">
  <a href="http://leafo.net/lapis">&laquo; Go To Homepage</a>
  &middot;
  <a href="https://github.com/leafo/lapis">GitHub Repository</a>
  &middot;
  <a href="https://github.com/leafo/lapis/issues">Issues Tracker</a>
</div>

[0]: http://openresty.org/
[1]: https://github.com/leafo/heroku-openresty
[2]: https://github.com/leafo/heroku-buildpack-lua
[3]: http://rocks.moonscript.org/modules/leafo/lapis
[4]: http://moonscript.org/reference/#moonc
[5]: http://www.postgresql.org/
[6]: https://github.com/leafo/lapis-console

