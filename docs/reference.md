
# Lapis Guide

Lapis is a web framework written in MoonScript. It is designed to be used with
MoonScript but can also works fine with Lua. Lapis is interesting because it's
built on top of the Nginx distribution [OpenResty][0]. Your web application is
run directly inside of Nginx. Nginx's event loop lets you make asynchronous
HTTP requests, database queries and other requests using the modules provided
with OpenResty. Lua's coroutines allows you to write synchronous looking code
that is event driven behind the scenes.

Lapis is early in development but it comes with a url router, html templating
through a MoonScript DSL, CSRF and session support, a basic PostgreSQL backed
active record system for working with models and a handful of other useful
functions needed for developing websites.

This guide hopes to serve as a tutorial and a reference.

## Basic Setup

Install OpenResty onto your system. If you're compiling manually it's
recommended to enable Postgres and Lua JIT. If you're using Heroku then you can
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

When we refer to a Lapis application we are talking about a class that extends
from `lapis.Application`. The properties of the application make up the routes
the application can serve and the actions it will perform.

If a property name is a string and begins with a "/" or the property is a table
then it defines a route. All other properties are methods of the application.

Let's start with the basic application from above:

    ```moon
    lapis = require "lapis"
    lapis.serve class extends lapis.Application
      "/": => "Hello World!"
    ```

[Named routes](#named_routes) are constructed using a table as a property name.

### URL Parameters

Routes can contain special patterns that match parts of the url and put them
into a request parameter.

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

You are free to add as many as you like by calling `@before_filter`
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

## Database Access

Lapis comes with a set of classes and functions for working with
[PostgreSQL][5]. In the future other databases might be directly supported.

### Configuring Upstream

Every query is performed asynchronously by sending a request to an Nginx
upstream. Our single upstream will automatically manage a pool of PostgreSQL
database connections.

The first step is to add an upstream to our `nginx.conf`. Place the following
in the `http` block:

    ```nginx
    upstream database {
      postgres_server ${{pg POSTGRESQL_URL}};
    }
    ```

> The upstream must be named `database` by default.

In this example the `pg` filter is applied to our `POSTGRESQL_URL`
configuration variable. Let's go ahead and add a value to our `config.moon`

    ```moon
    config "development", ->
      postgresql_url "postgres://postgres:@127.0.0.1/my_database"
    ```

The `pg` filter will convert the PostgreSQL URL to the right format for the
Nginx PostgreSQL module.

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

The same as `query` except it appends `"SELECT" to the front of the query.

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

If you want to use a different table name you can overwrite the `@table_name` class method:

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


[0]: http://openresty.org/
[1]: https://github.com/leafo/heroku-openresty
[2]: https://github.com/leafo/heroku-buildpack-lua
[3]: http://rocks.moonscript.org/modules/leafo/lapis
[4]: http://moonscript.org/reference/#moonc
[5]: http://www.postgresql.org/

