title: Database Access
--
# Database Access

Lapis comes with a set of classes and functions for working with
[PostgreSQL](http://www.postgresql.org/). In the future other databases will be
directly supported. In the meantime you're free to use other OpenResty database
drivers, you just won't have access to Lapis' query API.

Every query is performed asynchronously through the [OpenResty cosocket
API](http://wiki.nginx.org/HttpLuaModule#ngx.socket.tcp). A request will yield
and resume automatically so there's no need to code with callbacks, queries can
be written sequentially as if they were in a synchronous environment. Additionally
connections to the server are automatically pooled for optimal performance.

[*pgmoon*](https://github.com/leafo/pgmoon) is the driver used in Lapis for
communicating with PostgreSQL. It has the advantage of being able to be used
within OpenResty's cosocket API in addition to on the command line using
LuaSocket's synchronous API.

## Establishing A Connection

The first step is to define the configuration for our server in the `postgres`
block in our <span class="for_moon">`config.moon`</span><span
class="for_lua">`config.lua`</span> file.

```lua
-- config.lua
config("development", {
  postgres = {
    backend = "pgmoon",
    host = "127.0.0.1",
    user = "pg_user",
    password = "the_password",
    database = "my_database"
  }
})
```

```moon
-- config.moon
config "development", ->
  postgres ->
    backend "pgmoon"
    host "127.0.0.1"
    user "pg_user"
    password "the_password"
    database "my_database"
```

`host` defaults to `127.0.0.1` and `user` defaults to `postgres`, so you can
leave those fields out if they aren't different from the defaults. If a
non-default port is required it can be appended to the `host` with colon
syntax: `my_host:1234` (Otherwise `5432`, the PostgreSQL default, is used).

You're now ready to start making queries.

## Making a Query

There are two ways to make queries:

1. The raw query interface is a collection of functions to help you write SQL.
1. The [`Model` class](#models) is a wrapper around a Lua table that helps you synchronize it with a row in a database table.

The `Model` class is the preferred way to interact with the database. The raw
query interface is for achieving things the `Model` class in unable to do
easily.

Here's an example of the raw query interface:

```lua
local lapis = require("lapis")
local db = require("lapis.db")

local app = lapis.Application()

app:match("/", function()
  local res = db.query("select * from my_table where id = ?", 10)
  return "ok!"
end)
```

```moon
lapis = require "lapis"
db = require "lapis.db"

class extends lapis.Application
  "/": =>
    res = db.query "select * from my_table where id = ?", 10
    "ok!"
```

And the same query represented with the `Model` class:

```lua
local lapis = require("lapis")
local Model = require("lapis.db.model").Model

local app = lapis.Application()

local MyTable = Model:extend("my_table")

app:match("/", function()
  local row = MyTable:find(10)
  return "ok!"
end)
```

```moon
lapis = require "lapis"
import Model from require "lapis.db.model"

class MyTable extends Model

class extends lapis.Application
  "/": =>
    row = MyTable\find 10
    "ok!"
```


By default all queries will log to the Nginx notice log. You'll be able to see
each query as it happens.

## Query Interface

```lua
local db = require("lapis.db")
```

```moon
db = require "lapis.db"
```

The `db` module provides the following functions:

### `query(query, params...)`

Performs a raw query. Returns the result set if successful, returns `nil` if
failed.

The first argument is the query to perform. If the query contains any `?`s then
they are replaced in the order they appear with the remaining arguments. The
remaining arguments are escaped with `escape_literal` before being
interpolated, making SQL injection impossible.

```lua
local res

res = db.query("SELECT * FROM hello")
res = db.query("UPDATE things SET color = ?", "blue")
res = db.query("INSERT INTO cats (age, name, alive) VALUES (?, ?, ?)", 25, "dogman", true)
```

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

A query that fails to execute will raise a Lua error. The error will contain
the message from PostgreSQL along with the query.

### `select(query, params...)`

The same as `query` except it appends `"SELECT"` to the front of the query.

```lua
local res = db.select("* from hello where active = ?", db.FALSE)
```

```moon
res = db.select "* from hello where active = ?", db.FALSE
```

```sql
SELECT * from hello where active = FALSE
```

### `insert(table, values, returning...)`

Inserts a row into `table`. `values` is a Lua table of column names and values.

```lua
db.insert("my_table", {
  age = 10,
  name = "Hello World"
})
```


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

```lua
local res = db.insert("some_other_table", {
  name = "Hello World"
}, "id")
```

```moon
res = db.insert "some_other_table", {
  name: "Hello World"
}, "id"
```

```sql
INSERT INTO "some_other_table" ("name") VALUES ('Hello World') RETURNING "id"
```

### `update(table, values, conditions, params...)`

Updates `table` with `values` on all rows that match `conditions`.

```lua
db.update("the_table", {
  name = "Dogbert 2.0",
  active = true
}, {
  id = 100
})

```

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

```lua
db.update("the_table", {
  count = db.raw("count + 1")
}, "count < ?", 10)
```

```moon
db.update "the_table", {
  count: db.raw"count + 1"
}, "count < ?", 10
```

```sql
UPDATE "the_table" SET "count" = count + 1 WHERE count < 10
```

### `delete(table, conditions, params...)`

Deletes rows from `table` that match `conditions`.

```lua
db.delete("cats", { name: "Roo"})
```

```moon
db.delete "cats", name: "Roo"
```

```sql
DELETE FROM "cats" WHERE "name" = 'Roo'
```

`conditions` can also be a string

```moon
db.delete("cats", "name = ?", "Gato")
```

```moon
db.delete "cats", "name = ?", "Gato"
```

```sql
DELETE FROM "cats" WHERE name = 'Gato'
```

### `raw(str)`

Returns a special value that will be inserted verbatim into the query without being
escaped:

```lua
db.update("the_table", {
  count = db.raw("count + 1")
})

db.select("* from another_table where x = ?", db.raw("now()"))
```

```moon
db.update "the_table", {
  count: db.raw"count + 1"
}

db.select "* from another_table where x = ?", db.raw"now()"
```

```sql
UPDATE "the_table" SET "count" = count + 1
SELECT * from another_table where x = now()
```

### `escape_literal(value)`

Escapes a value for use in a query. A value is any type that can be stored in a
column. Numbers, strings, and booleans will be escaped accordingly.

```lua
local escaped = db.escape_literal(value)
local res = db.query("select * from hello where id = " .. escaped")
```

```moon
escaped = db.escape_literal value
res = db.query "select * from hello where id = #{escaped}"
```

`escape_literal` is not appropriate for escaping column or table names. See
`escape_identifier`.

### `escape_identifier(str)`

Escapes a string for use in a query as an identifier. An identifier is a column
or table name.

```lua
local table_name = db.escape_identifier("table")
local res = db.query("select * from " .. table_name)
```

```moon
table_name = db.escape_identifier "table"
res = db.query "select * from #{table_name}"
```

`escape_identifier` is not appropriate for escaping values. See
`escape_literal` for escaping values.

### Constants

The following constants are also available:

 * `NULL` -- represents `NULL` in SQL
 * `TRUE` -- represents `TRUE` in SQL
 * `FALSE` -- represents `FALSE` in SQL


```lua
db.update("the_table", {
  name = db.NULL
})
```

```moon
db.update "the_table", {
  name: db.NULL
}
```

## Models

Lapis provides a `Model` base class for making Lua tables that can be
synchronized with a database row. The class is used to represent a single
database table, an instance of the class is used to represent a single row of
that table.

The most primitive model is a blank model:


```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users")
```

```moon
import Model from require "lapis.db.model"

class Users extends Model
```

<p class="for_lua">
The first argument to <code>extend</code> is the name of the table to associate
the model to.
</p>

<p class="for_moon">
The name of the class is used to determine the name of the table. In this case
the class name <code>Users</code> represents the table <code>users</code>. A
class name of <code>HelloWorlds</code> would result in the table name
<code>hello_worlds</code>. It is customary to make the class name plural.
</p>

<p class="for_moon">
If you want to use a different table name you can overwrite the
<code>@table_name</code> class method:
</p>

```moon
class Users extends Model
  @table_name: => "active_users"
```

### Primary Keys

By default all models have the primary key "id". This can be changed by setting
the <span class="for_moon">`@primary_key`</span><span
class="for_lua">`self.primary_key`</span> class variable.


```lua
local Users = Model:extend("users", {
  primary_key = "login"
})
```

```moon
class Users extends Model
  @primary_key: "login"
```

If there are multiple primary keys then an array table can be used:

```lua
local Followings = Model:extend("followings", {
  primary_key = { "user_id", "followed_user_id" }
})
```

```moon
class Followings extends Model
  @primary_key: { "user_id", "followed_user_id" }
```

### Finding a Row

For the following examples assume we have the following models:

```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users")

local Tags = Model:extend("tags", {
  primary_key = {"user_id", "tag"}
})

```


```moon
import Model from require "lapis.db.model"

class Users extends Model

class Tags extends Model
  @primary_key: {"user_id", "tag"}
```

When you want to find a single row the `find` class method is used. In the
first form it takes a variable number of values, one for each primary key in
the order the primary keys are specified:

```lua
local user = Users:find(23232)
local tag = Tags:find(1234, "programmer")
```

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

We can also pass a table as an argument to `find`. The table will be converted
to a `WHERE` clause in the query:


```lua
local user = Users:find({ email = "person@example.com" })
```

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

```lua
local tags = Tags:select("where tag = ?", "merchant")
```

```moon
tags = Tags\select "where tag = ?", "merchant"
```

```sql
SELECT * from "tags" where tag = 'merchant'
```

Instead of a single instance, an array table of instances is returned.

If you want to restrict which columns are selected you can pass in a table as
the last argument with the `fields` key set:

```lua
local tags = Tags:select("where tag = ?", "merchant", { fields = "created_at as c" })
```

```moon
tags = Tags\select "where tag = ?", "merchant", fields: "created_at as c"
```

```sql
SELECT created_at as c from "tags" where tag = 'merchant'
```

Alternatively if you want to find many rows by their primary key you can use
the `find_all` method. It takes an array table of primary keys. This method
only works on tables that have singular primary keys.

```lua
local users = Users:find_all({ 1,2,3,4,5 })
```

```moon
users = Users\find_all { 1,2,3,4,5 }
```

```sql
SELECT * from "users" where "id" in (1, 2, 3, 4, 5)
```

If you need to find many rows for another column other than the primary key you
can pass in the optional second argument:


```lua
local users = UserProfile:find_all({ 1,2,3,4,5 }, "user_id")
```

```moon
users = UserProfile\find_all { 1,2,3,4,5 }, "user_id"
```

```sql
SELECT * from "UserProfile" where "user_id" in (1, 2, 3, 4, 5)
```

The second argument can also be a table of options. The following properties
are supported:

* `key` -- Specify the column name to find by, same effect as passing in a string as the second argument
* `fields` -- Comma separated list of column names to fetch instead of the default `*`
* `where` -- A table of additional `where` clauses for the query

For example:

```lua
local users = UserProfile:find_all({1,2,3,4}, {
  key = "user_id",
  fields = "user_id, twitter_account",
  where = {
    public = true
  }
})
```

```moon
users = UserProfile\find_all {1,2,3,4}, {
  key: "user_id"
  fields: "user_id, twitter_account"
  where: {
    public: true
  }
}
```

```sql
SELECT user_id, twitter_account from "things" where "user_id" in (1, 2, 3, 4) and "public" = TRUE
```

### Inserting Rows

The `create` class method is used to create new rows. It takes a table of
column values to create the row with. It returns an instance of the model. The
create query fetches the values of the primary keys and sets them on the
instance using the PostgreSQL `RETURN` statement. This is useful for getting
the value of an auto-incrementing key from the insert statement.

```lua
local user = Users:create({
  login = "superuser",
  password = "1234"
})
```

```moon
user = Users\create {
  login: "superuser"
  password: "1234"
}
```

```sql
INSERT INTO "users" ("password", "login") VALUES ('1234', 'superuser') RETURNING "id"
```

### Updating a Row

Instances of models have the `update` method for updating the row. The values
of the primary keys are used to uniquely identify the row for updating.

The first form of update takes variable arguments. A list of strings that
represent column names to be updated. The values of the columns are taken from
the current values in the instance.

```lua
local user = Users:find(1)
user.login = "uberuser"
user.email = "admin@example.com"
user:update("login", "email")
```

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
columns with. The instance is also updated. We can rewrite the above example as:

```lua
local user = Users:find(1)
user:update({
  login = "uberuser",
  email = "admin@example.com",
})
```

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

### Deleting a Row

Just call `delete` on the instance:

```lua
local user = Users:find(1)
user:delete()
```

```moon
user = Users\find 1
user\delete!
```

```sql
DELETE FROM "users" WHERE "id" = 1
```

### Timestamps

Because it's common to store creation and update times, models have
support for managing these columns automatically.

When creating your table make sure your table has the following columns:


```sql
CREATE TABLE ... (
  ...
  "created_at" timestamp without time zone NOT NULL,
  "updated_at" timestamp without time zone NOT NULL
)
```

Then define your model with the <span class="for_moon">`@timestamp` class
variable</span><span class="for_lua">`timestamp` property</span> set to
true:

```lua
local Users = Model:extend("users", {
  timestamp = true
})
```

```moon
class Users extends Model
  @timestamp: true
```

Whenever `create` and `update` are called the appropriate timestamp column will
also be set.

You can disable the timestamp from being updated on an `update` by passing a
final table argument setting <span class="for_moon">`timestamp:
false`</span><span class="for_lua">`timestamp = false`</span>:


```lua
local Users = Model:extend("users", {
  timestamp = true
})

local user = Users:find(1)

-- first form
user:update({ name = "hello world" }, { timestamp = false })


-- second form
user.name = "hello world"
user.age = 123
user:update("name", "age", { timestamp = false})
```

```moon
class Users extends Model
  @timestamp: true

user = Users\find 1

-- first form
user\update { name: "hello world" }, { timestamp: false }

-- second form
user.name = "hello world"
user.age = 123
user\update "name", "age", timestamp: false
```

### Preloading Associations

A common pitfall when using active record type systems is triggering many
queries inside of a loop. In order to avoid situations like this you should
load data for as many objects as possible in a single query before looping over
the data.

We'll need some models to demonstrate: (The columns are annotated in a comment
above the model).

```lua
local Model = require("lapis.db.model").Model

-- table with columns: id, name
local Users = Model:extend("users")
local Posts = Model:extend("posts")
```

```moon
import Model from require "lapis.db.model"

-- table with columns: id, name
class Users extends Model

-- table with columns: id, user_id, text_content
class Posts extends Model
```

Given all the posts, we want to find the user for each post. We use the
`include_in` class method to include instances of that model in the array of
model instances passed to it.

```lua
local posts = Posts:select() -- this gets all the posts
Users:include_in(posts, "user_id")

print(posts[1].user.name) -- print the fetched data
```

```moon
posts = Posts\select! -- this gets all the posts

Users\include_in posts, "user_id"

print posts[1].user.name -- print the fetched data
```

```sql
SELECT * from "posts"
SELECT * from "users" where "id" in (1,2,3,4,5,6)
```

Each post instance is mutated to have a `user` property assigned to it with an
instance of the `Users` model. The first argument of `include_in` is the array
table of model instances. The second argument is the column name of the foreign
key found in the array of model instances that maps to the primary key of the
class calling the `include_in`.

The name of the inserted property is derived from the name of the foreign key.
In this case, `user` was derived from the foreign key `user_id`. If we want to
manually specify the name we can do something like this:


```lua
Users:include_in(posts, "user_id", { as: "author" })
```

```moon
Users\include_in posts, "user_id", as: "author"
```

Now all the posts will contain a property named `author` with an instance of
the `Users` model.

Sometimes the relationship is flipped. Instead of the list of model instances
having the foreign key column, the model we want to include might have it. This
is common in one-to-one relationships.

Here's another set of example models:

```lua
local Model = require("lapis.db.model").Model

-- table with columns: id, name
local Users = Model:extend("users")

-- table with columns: user_id, twitter_account, facebook_username
local UserData = Model:extend("user_data")

```

```moon
import Model from require "lapis.db.model"

-- columns: id, name
class Users extends Model

-- columns: user_id, twitter_account, facebook_username
class UserData extends Model
```

Now let's say we have a collection of users and we want to fetch the associated
user data:

```lua
local users = Users:select()
UserData:include_in(users, "user_id", { flip: true })

print(users[1].user_data.twitter_account)
```

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

```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  constraints = {
    name = function(self, value)
      if value:lower() == "admin"
        return "User can not be named admin"
      end
    end
  }
})

assert(Users:create({
  name = "Admin"
}))

```

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

The <span class="for_moon">`@constraints` class variable</span><span class="for_lua">`constraints` property</span> is a table that maps column name to a
function that should check if the constraint is broken. If anything truthy is
returned from the function then the update/insert fails, and that is returned
as the error message.

In the example above, the call to `assert` will fail with the error `"User can
not be named admin"`.

The constraint check function is passed 4 arguments. The model class, the value
of the column being checked, the name of the column being checked, and lastly
the object being checked. On insertion the object is the table passed to the
create method. On update the object is the instance of the model.

### Pagination

Using the `paginated` method on models we can easily paginate through a query
that might otherwise return many results. The arguments are the same as the
`select` method but instead of the result it returns a special `Paginator`
object.

For example, say we have the following table and model: (For documentation on
creating tables see the [next section](#database-schemas-creating-and-dropping-tables))

```lua
create_table("users", {
  { "id", types.serial },
  { "name", types.varchar },
  { "group_id", types.foreign_key },

  "PRIMARY KEY(id)"
})

local Users = Model:extend("users")
```


```moon
create_table "users", {
  { "id", types.serial }
  { "name", types.varchar }
  { "group_id", types.foreign_key }

  "PRIMARY KEY(id)"
}

class Users extends Model

```

We can create a paginator like so:

```lua
local paginated = Users:paginated("where group_id = ? order by name asc", 123)
```

```moon
paginated = Users\paginated [[where group_id = ? order by name asc]], 123
```

A paginator can be configured by passing a table as the last argument.
The following options are supported:

`per_page`: sets the number of items per page

```moon
local paginated_alt = Users:paginated("where group_id = ?", 4, { per_page = 100 })
```

```moon
paginated_alt = Users\paginated [[where group_id = ?]], 4, per_page: 100
```

`prepare_results`: a function that is passed the results of `get_page` and
`get_all` for processing before they are returned. This is useful for bundling
preloading information into the paginator. The prepare function takes 1
argument, the results, and it must return the results after they have been
processed:


```lua
local preloaded = Posts:paginated("where category = ?", "cats", {
  per_page = 10,
  prepare_results = function(posts)
    Users:include_in(posts, "user_id")
    return posts
  end
})
```

```moon
preloaded = Posts\paginated [[where category = ?]], "cats", {
  per_page: 10
  prepare_results: (posts) ->
    Users\include_in posts, "user_id"
    posts
}
```

Any additional options sent to `paginated` are passed directly to the
underlying `select` method call when a page is loaded. For example you can
provide a `fields` option in order to limit the fields returned by a page.

The paginator has the following methods:

#### `get_all()`

Gets all the items that the query can return, is the same as calling the
`select` method directly. Returns an array table of model instances.

```lua
local users = paginated:get_all()
```

```moon
users = paginated\get_all!
```

```sql
SELECT * from "users" where group_id = 123 order by name asc
```

#### `get_page(page_num)`

Gets `page_num`th page, where pages are 1 indexed. The number of items per page
is controlled by the `per_page` option, and defaults to 10. Returns an array
table of model instances.

```lua
local page1 = paginated:get_page(1)
local page6 = paginated:get_page(6)
```

```moon
page1 = paginated\get_page 1
page6 = paginated\get_page 6
```

```sql
SELECT * from "users" where group_id = 123 order by name asc limit 10 offset 0
SELECT * from "users" where group_id = 123 order by name asc limit 10 offset 50
```

#### `num_pages()`

Returns the total number of pages.

#### `total_items()`

Gets the total number of items that can be returned. The paginator will parse
the query and remove all clauses except for the `WHERE` when issuing a `COUNT`.

```lua
local users = paginated:total_items()
```

```moon
users = paginated\total_items!
```

```sql
SELECT COUNT(*) as c from "users" where group_id = 123
```

#### `each_page(starting_page=1)`

Returns an iterator function that can be used to iterate through each page of
the results. Useful for processing a large query without having the entire
result set loaded in memory at once.

```lua
for page_results, page_num in paginated:each_page() do
  print(page_results, page_num)
end
```

```moon
for page_results, page_num in paginated\each_page!
  print(page_results, page_num)
```

### Describing Relationships

You can describe relationships between models using the `relations` class
property.

```lua
local Model = require("lapis.db.model").Model
local Posts = Model:extend("posts", {
  relations = {
    {"users", belongs_to = "Users"}
  }
})

```

```moon
import Model from require "lapis.db.models"
class Posts extends Model
  @relations: {
    {"user", belongs_to: "Users"}
  }
```

Relations will automatically add methods to models to make fetching the
associated model instances easy. For example the `belongs_to` relation from the
example above would make a `get_user` getter:


```lua
local post = Posts:find(1)
local user = post:get_user()

-- calling again returns the cached value
local user = post:get_user()
```

```moon
post = Posts\find 1
user = post\get_user!

-- calling again returns the cached value
user = post\get_user!
```

```sql
SELECT * from "posts" where "id" = 1;
SELECT * from "users" where "id" = 123;
```

The following relations are available

#### `belongs_to`

A one-to-one relation where the foreign key is located on the current model.

```moon
import Model from require "lapis.db.models"
class Users extends Model
class Posts extends Model
  @relations: {
    {"user", belongs_to: "Users"}
  }
```

Creates `get_` method for each relation.

```moon
user = post\get_user!
```

```sql
SELECT * from "users" where "user_id" = 123;
```

#### `has_one`

A one-to-one relation where the foreign key is located on the associated model.

```moon
import Model from require "lapis.db.models"
class Users extends Model
  @relations: {
    {"user_profile", has_one: "UserProfiles"}
  }

class UserProfiles extends Model
```

Creates `get_` method for each relation.

```moon
profile = user\get_user_profile!
```

```sql
SELECT * from "user_profiles" where "user_id" = 123;
```

By default, the relation converts the name of the table to a foreign key column
name by making it singular and appending `_id`. The table `users` would convert
to `user_id`. Sometimes the calculated foreign key isn't correct, you can
provide a custom key with the `key` parameter to the relation:

```moon
import Model from require "lapis.db.models"
class Users extends Model
  @relations: {
    {"user_profile", has_one: "UserProfiles", key: "owner_id"}
  }

class UserProfiles extends Model
```

```sql
SELECT * from "user_profiles" where "owner_id" = 123;
```

#### `has_many`

A one to many relation, returns a `Pager` object.

#### `fetch`

A custom relation, provide a function to fetch the associated data. Result is cached.

```moon
import Model from require "lapis.db.models"
class Users extends Model
  @relations: {
    {"recent_posts", fetch: =>
			-- fetch some data
		}
  }
```

### Finding Columns

You can get the column names and column types of a table using the `columns`
method on the model class:

```lua
local Posts = Model:extend("posts")
for _, col in ipairs(Posts:columns) do
  print(col.column_name, col.data_type)
end
```

```moon
class Posts extends Model

for {column_name, data_type} in Posts\columns!
  print column_name, data_type
```

```sql
SELECT column_name, data_type
  FROM information_schema.columns WHERE table_name = 'posts'
```

### Refreshing a Model Instance

If your model instance becomes out of date from an external change, it can tell
it to re-fetch and re-populate it's data using the `refresh` method.

```moon
class Posts extends Model
post = Posts\find 1
post\refresh!
```

```lua
local Posts = Model:extend("posts")
local post = Posts:find(1)
post:refresh()
```

```sql
SELECT * from "posts" where id = 1
```

By default all fields are refreshed. If you only want to refresh specific fields
then pass them in as arguments:


```moon
class Posts extends Model
post = Posts\find 1
post\refresh "color", "height"
```

```lua
local Posts = Model:extend("posts")
local post = Posts:find(1)
post:refresh("color", "height")
```

```sql
SELECT "color", "height" from "posts" where id = 1
```

## Database Schemas

Lapis comes with a collection of tools for creating your database schema inside
of the `lapis.db.schema` module.

### Creating and Dropping Tables

#### `create_table(table_name, { table_declarations... })`

The first argument to `create_table` is the name of the table and the second
argument is an array table that describes the table.

```lua
local schema = require("lapis.db.schema")

local types = schema.types

schema.create_table("users", {
  {"id", types.serial},
  {"username", types.varchar},

  "PRIMARY KEY (id)"
})
```

```moon
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
For example, `schema.types.varchar` evaluates to `character varying(255) NOT
NULL`. See more about types below.

If the value to the second argument is a string then it is inserted directly
into the `CREATE TABLE` statement, that's how we create the primary key above.

#### `drop_table(table_name)`

Drops a table.

```lua
schema.drop_table("users")
```

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

```lua
local create_index = schema.create_index

create_index("users", "created_at")
create_index("users", "username", { unique = true })

create_index("posts", "category", "title")
create_index("uploads", "name", { where = "not deleted" })
```

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

```lua
local drop_index = schema.drop_index

drop_index("users", "created_at")
drop_index("posts", "title", "published")
```

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

```lua
schema.add_column("users", "age", types.integer)
```

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

```lua
schema.drop_column("users", "age")
```

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

```lua
schema.rename_column("users", "age", "lifespan")
```

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

```lua
schema.rename_table("users", "members")
```

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


```lua
local types = require("lapis.db.schema").types

types.boolean       --> boolean NOT NULL DEFAULT FALSE
types.date          --> date NOT NULL
types.double        --> double precision NOT NULL DEFAULT 0
types.foreign_key   --> integer NOT NULL
types.integer       --> integer NOT NULL DEFAULT 0
types.numeric       --> numeric NOT NULL DEFAULT 0
types.real          --> real NOT NULL DEFAULT 0
types.serial        --> serial NOT NULL
types.text          --> text NOT NULL
types.time          --> timestamp without time zone NOT NULL
types.varchar       --> character varying(255) NOT NULL
```

```moon
import types from require "lapis.db.schema"

types.boolean       --> boolean NOT NULL DEFAULT FALSE
types.date          --> date NOT NULL
types.double        --> double precision NOT NULL DEFAULT 0
types.foreign_key   --> integer NOT NULL
types.integer       --> integer NOT NULL DEFAULT 0
types.numeric       --> numeric NOT NULL DEFAULT 0
types.real          --> real NOT NULL DEFAULT 0
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

```lua
types.integer({ default = 1, null = true })  --> integer DEFAULT 1
types.integer({ primary_key = true })        --> integer NOT NULL DEFAULT 0 PRIMARY KEY
types.text({ null = true })                  --> text
types.varchar({ primary_key = true })        --> character varying(255) NOT NULL PRIMARY KEY
```

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

We define migrations in our code as a table of functions where the key of each
function in the table is the name of the migration. You are free to name the
migrations anything but it's suggested to give them Unix timestamps as names:

```lua
local schema = require("lapis.db.schema")

return {
  [1368686109] = function()
    schema.add_column("my_table", "hello", schema.types.integer)
  end,

  [1368686843] = function()
    schema.create_index("my_table", "hello")
  end
}
```

```moon
import add_column, create_index, types from require "lapis.db.schema"

{
  [1368686109]: =>
    add_column "my_table", "hello", types.integer

  [1368686843]: =>
    create_index "my_table", "hello"
}
```

A migration function is a plain function. Generally they will call the
schema functions described above, but they don't have to.

Only the functions that haven't already been executed will be called when we
tell our migrations to run. The migrations that have already been run are
stored in the migrations table, a database table that holds the names of the
migrations that have already been run. Migrations are run in the order of their
keys sorted ascending.

### Running Migrations

The Lapis command line tool has a special command for running migrations. It's
called `lapis migrate`.

This command expects a module called `migrations` that returns a table of
migrations in the format described above.

Let's create this file with a single migration as an example.

```lua
-- migrations.lua

local schema = require("lapis.db.schema")
local types = schema.types

return {
  [1] = function()
    schema.create_table("articles", {
      { "id", types.serial },
      { "title", types.text },
      { "content", types.text },

      "PRIMARY KEY (id)"
    })
  end
}
```

```moon
-- migrations.moon

import create_table, types from require "lapis.db.schema"

{
  [1]: =>
    create_table "articles", {
      { "id", types.serial }
      { "title", types.text }
      { "content", types.text }

      "PRIMARY KEY (id)"
    }
}
```

After creating the file, ensure that it is compiled to Lua and run `lapis
migrate`. The command will first create the migrations table if it doesn't
exist yet then it will run every migration that hasn't been executed yet.

Read more about [the migrate command](#command-line-interface-lapis-migrate).

### Manually Running Migrations

We can manually create the migrations table using the following code:

```lua
local migrations = require("lapis.db.migrations")
migrations.create_migrations_table()
```

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

Then we can manually run migrations with the following code:

```lua
local migrations = require("lapis.db.migrations")
migrations.run_migrations(require("migrations"))
```

```moon
import run_migrations from require "lapis.db.migrations"
run_migrations require "migrations"
```
