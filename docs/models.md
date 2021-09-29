{
  title: "Models"
}

# Models

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


Model instances will have a field for each column that has been fetched from
the database. You do not need to manually specify the names of the columns.  If
you have any relationships, though, you can specify them using the
[`relations` property](#relations).

## Primary Keys

By default all models expect the table to have a primary key called`"id"`. This
can be changed by setting the <span class="for_moon">`@primary_key`</span><span
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

A unique primary key is needed for every row in order to `update` and `delete`
rows without affecting other rows unintentially.

## Class Methods

Model class methods are used for fetching existing rows, creating new ones, or
fetching data about the underlying table.

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

### `find(...)`

The `find` class method fetches a single row from the table by some condition.
Pass the values of the primary keys you want to look up by in the order
specified by the `primary_keys` assigned in the Model's class.

> A model without user defined primary keys has the primary key of `id` by
> default. For those models, `find` would take one argument, the value of `id`.


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

`find` returns an instance of the model if it could be found, `nil` otherwise.

An alternate way of calling find is to pass a table as the first argument. The
table will be converted to a `WHERE` clause in the query:

```lua
local user = Users:find({ email = "person@example.com" })
```

```moon
user = Users\find email: "person@example.com"
```

```sql
SELECT * from "users" where "email" = 'person@example.com' limit 1
```

Like all database finders, you are free to use `db.raw` to embed raw SQL. For
example, you might perform a case insensitive email search like so:


```lua
local user = Users:find({ [db.raw("lower(email)")] = some_email:lower() })
```

```moon
user = Users\find [db.raw "lower(email)"]: some_email\lower!
```

```sql
SELECT * from "users" where lower(email) = 'person@example.com' limit 1
```

### `select(query, ...)`

When searching for multiple rows the `select` class method is used. It works
similarly to the [`select` function from the raw query
interface](database.html#query-interface-selectquery-params) except you specify
the part of the query after the list of columns to select.

```lua
local tags = Tags:select("where tag = ?", "merchant")
```

```moon
tags = Tags\select "where tag = ?", "merchant"
```

```sql
SELECT * from "tags" where tag = 'merchant'
```

Instead of a single instance, an array table of instances is returned. If there
are no matching rows an empty table is returned.

If you want to restrict which columns are selected, you can pass in a table as
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

The `fields` option is inserted into the SQL statement as is, so do not use
untrusted strings otherwise you may be vulnerable to SQL injection. Use
[`db.escape_identifier`](database.html#query-interface/escape_identifier) to
escape column names.

You can use the `load` option to change what model each result of the query is
loaded as. By default it will convert each row to an instance of the model that
is calling the `select` method. Passing `false` to load will return the results
unaffected, as plain Lua tables.

### `find_all(primary_keys)`

If you want to find many rows by their primary key you can use the `find_all`
method. It takes an array table of primary keys. This method only works on
tables that have singular primary keys unless you explicitly pass a column to
search by.

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

$options_table{
  {
    name = "key",
    description = "Specify the column name to find by, same effect as passing in a string as the second argument. The column name will be escaped with `db.escape_literal`.",
    default = "the table's primary key"
  },
  {
    name = "fields",
    description = "A string of raw SQL inserted directly after the `SELECT` portion of the query. Use this to control what fields are returned",
    default = "`*`"
  },
  {
    name = "where",
    description = "A table of additional `where` clauses for the query"
  },
  {
    name = "clause",
    description = "A raw SQL fragment to append to query either as string, or array table of arguments to be passed to `db.interpolate_query`"
  }
}

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

### `count(clause, ...)`

Counts the number of records in the table that match the clause.

```lua
local total = Users:count()
local count = Users:count("username like '%' || ? || '%'", "leafo")
```

```moon
total = Users\count!
count = Users\count "username like '%' || ? || '%'", "leafo"
```

```sql
SELECT COUNT(*) "users"
SELECT COUNT(*) "users" where username like '%' || 'leafo' || '%'
```

### `create(values, create_opts=nil)`

The `create` class method is used to create new rows. It takes a table of
column values to create the row with. It returns an instance of the model. The
create query fetches the values of the primary keys and sets them on the
instance using the PostgreSQL `RETURNING` statement. This is useful for getting
the value of an auto-incrementing key from the insert statement.

> In MySQL the *last insert id* is used to get the id of the row since the
> `RETURNING` statement is not available.

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

If any of the column values are
[`db.raw`](database.html#query-interface-rawstr) then their computed values
will also be fetched using the `RETURN` clause of the `CREATE` statement. The
raw values are replaced by the values returned by the database.

For example, we might create a new row in a table with a `position` column set
to the next highest number:


```lua
local user = Users:create({
  position = db.raw("(select coalesce(max(position) + 1, 0) from users)")
})
```

```moon
user = Users\create {
  position: db.raw "(select coalesce(max(position) + 1, 0) from users)"
}
```

```sql
INSERT INTO "users" (position)
VALUES ((select coalesce(max(position) + 1, 0) from users))
RETURNING "id", "position"
```

> Since `RETURNING` is not available in MySQL, this functionality is PostgreSQL
> specific.

If your model has any [constraints](#constraints) they will be checked before trying to create
a new row. If a constraint fails then `nil` and the error message are returned
from the `create` function.

`create` can take an options table as a second argument. It supports the
following options:

* `returning` -- A string containing a list of columns to fetch along with the create statement using the `RETURNING` statement


### `columns()`

Returns all the columns on the table. Returns an array of tables that contain
column names and their types.

```lua
local cols = Users:columns()
```

```moon
cols = Users\columns!
```

```sql
SELECT column_name, data_type
  FROM information_schema.columns WHERE table_name = 'users'
```

The output might look like this:


```lua
{
  {
    data_type = "integer",
    column_name = "id"
  },
  {
    data_type = "text",
    column_name = "name"
  }
}
```

```moon
{
  {
    data_type: "integer",
    column_name: "id"
  }
  {
    data_type: "text",
    column_name: "name"
  }
}
```

> MySQL will return a slightly different format, but will contain the same information.

### `table_name()`

Returns the name of the table backed by the model.

```lua
Model:extend("users"):table_name() --> "users"
Model:extend("user_posts"):table_name() --> "user_posts"
```

```moon
(class Users extends Model)\table_name! --> "users"
(class UserPosts extends Model)\table_name! --> "user_posts"
```

<p class="for_moon">
This class method can be overridden to change what table a model uses:
</p>

```moon
class Users extends Model
  @table_name: => "active_users"
```

### `singular_name()`

Returns the singular name of the table.

```lua
Model:extend("users"):singular_name() --> "user"
Model:extend("user_posts"):singular_name() --> "user_post"
```

```moon
(class Users extends Model)\singular_name! --> "user"
(class UserPosts extends Model)\singular_name! --> "user_post"
```

The singular name is used internally by Lapis when calculating what the name of
the field is when loading rows with `include_in`. It's also used when
determining the foreign key column name with a `has_one` or `has_many`
relation.

### `include_in(objects, key, opts={})`

Bulk load rows of the model into an array of objects (often the array of
objects is an array of instances of another model). This is used to preload
associations in a single query in order to avoid the [n+1 queries
problem](https://leafo.net/guides/postgresql-preloading.html).

It works my mutating the objects in the array by inserting a new field into
each item where the query returned a result. The name of this new field is
either derived from the model's table name, or manually specified via an
option.

Returns the `objects` array table.

This is a lower level interface for preloading data on models. In general we
recommend [using relations](#describing-relationships) if possible. A relation
will internally generate a call to `include_in` based on how you have
configured the relation.

The `key` argument controls the mapping from the fields in each object of the
objects array to the column name used in the query. It can be a string, an
array of strings, or a string*(column)* → string*(field)* table mapping. When
using a string or array of strings then the corresponding associated key is
automatically chosen.

Possible values for `key` argument:

* **string** -- for each object, the value `object[key]` is used to lookup instances of the model by the model's primary key. The model is assumed to have a singular primary key, and will error otherwise
  * with `flip` enabled: `key` is used as the foreign key column name, and `object[opts.local_key or "id"]` is used to pull the values
* **array of string** -- for each object, a composite key is created by individually mapping each field of the key array via `object[key]` to the composite primary key of the model
* **column mapping table** -- explicitly specify the mapping of fields to columns. The *key* of the table will be used as the column name, and the value in the table will be used as the field name referenced from the `objects` argument

`include_in` supports the following options (via the optional `opts` argument):

$options_table{
  {
    name = "as",
    description = "The name of the field the loaded associated model is stored into",
    default = "generated from table name (eg. `Posts` → `post`)"
  },
  {
    name = "where",
    description = "A table of additional conditionals to limit the query by",
    example = dual_code{[[
      Users\include_in posts, "user_id", {
        where: {
          deleted: false
        }
      }
    ]]}
  },
  {
    name = "fields",
    description = "Raw SQL fragment to control which columns are returned by the query. `db.escape_identifier` can be used to sanitize column names",
    example = dual_code{[[
      Users\include_in posts, "user_id", {
        fields: "id, name as display_name, created_at"
      }
    ]]}
  },
  {
    name = "many",
    description = "set to `true` to fetch many records for each input model instance. The fetched models will be stored as an array on each preloaded object. An empty array is assigned when no rows are found"
  },
  {
    name = "value",
    description = "a function called for each fetched row where the return value is used in place of the row object when filling `objects`"
  },
  {
    name = "order",
    description = "the order of items when preloading a `many` preload. Taken as a raw SQL clause"
  },
  {
    name = "group",
    description = "group by clause. Taken as a raw SQL clause"
  },
  {
    name = "flip",
    description = "***(deprecated)*** Flips the use of the `key` argument (when a string), to be the column name instead of the field name. `flip` can not be used with an array or table `key` argument",
    default = "`false`"
  },
  {
    name = "local_key",
    description = "***(deprecated)*** only appropriate when `flip` is true. The name of the field to use when pulling primary keys from `objects`",
    default = [[`"id"`]]
  }
}

> `flip` & `local_key` are deprecated and will be removed in a future version of Lapis. You
> should opt to use the column mapping table instead of `flip` or `local_key`
> options.

<details class="aside">
<summary>How to migrate away from `flip` and `local_key`</summary>

Flip is confusing, and is deprecated and will be removed. These examples show
replacement calls to `include_in` that do not use flip.

The following are equivalent:

$dual_code{[[
UserData\include_in users, "user_id", flip: true
UserData\include_in users, user_id: "id"
]]}

The following use `local_key` and are equivalent:

$dual_code{[[
UserData\include_in users, "user_id", flip: true, local_key: "internal_id"
UserData\include_in users, user_id: "internal_id"
]]}

An easy way to think about the column mapping table is as a `where` clause
table but instead of having literal values you specify the name of the field
that is pulled from the array of objects.
</details>

In order to demonstrate `include_in` we'll need some models: (The columns are
annotated in a comment above the model).

```lua
local Model = require("lapis.db.model").Model

-- table with columns: id, name
local Users = Model:extend("users")

-- table with columns: id, user_id, text_content
local Posts = Model:extend("posts")
```

```moon
import Model from require "lapis.db.model"

-- table with columns: id, name
class Users extends Model

-- table with columns: id, user_id, text_content
class Posts extends Model
```

Given all the posts, we want to find the user for each post. `include_in` can
be called on the model we wish to load, `Users`, with the array of model
instances we want to fill: `posts`. The second argument is the name of the
foreign key on the array of model instances that points to the rows we are
preloading. By default, the value of the foreign key is mapped to the primary
key of the model that is being loaded.

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

The name of the inserted property is derived from the name of the foreign key.
In this case, `user` was derived from the foreign key `user_id`. If we want to
manually specify the name the `as` option can be used:

$dual_code{[[
Users\include_in posts, "user_id", as: "author"
]]}

Now all the posts will contain a property named `author` with an instance of
the `Users` model.

In this next example a column mapping table is used to explicitly specify what
fields in our object array match to the columns in our query. Here are the
relevant models:

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

Now let's say we have an array of users and we want to fetch the associated
user data.

$dual_code{[[
users = Users\select!
UserData\include_in users, user_id: "id"

print users[1].user_data.twitter_account
]]}

```sql
SELECT * from "user_data" where "user_id" in (1,2,3,4,5,6)
```

The second argument of `include_in`, called `key`, is a table with the value `{
"user_id" = "id"}`. This instructs `include_in` to take all the values stored
in the `id` field from the users array to use as values to look up rows in
`user_data` table by the `user_id` column.

The field name that is used to store each result in the users array is derived
from the name of the included table. In this case, `UserData` →  `user_data`.
This can be overridden by using the `as` option.

> The table name is converted to English singular form. Since user_data is both
> singular and plural, it's used as is.

One last common scenario is preloading a one-to-many relationship. You can use
the `many` option to instruct `include_in` to collect all associated results
for each input object into an array. (The derived field name will be plural)

For example, we might load all the posts for each user:

$dual_code{[[
users = Users\select!
Posts\include_in users, { user_id: "id" }, many: true
]]}

```sql
SELECT * from "posts" where "user_id" in (1,2,3,4,5,6)
```

Each `users` object will now have a `posts` field that is an array containing
all the associated posts that were found. (Note that `posts` is a plural
derived field name when `many` is true.)

### `paginated(query, ...)`

Similar to `select` but returns a `Paginator`. Read more in [Pagination](#pagination).

## Instance Methods

### `update(..., opts={})`

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

If any of the updated values are generated from raw SQL via `db.raw`, then
those values will be replaced with values returning by the database using the
`RETURNING` clause similar to the [`create` class
method](#class-methods-createopts).

**Options**

$options_table{
  {
    name = "timestamp",
    default = "`true`",
    description = "The `updated_at` field will be updated to the current time if the model has timestamps. Note that if the update itself contains `updated_at` then that will take precedence over the auto-update.",
    example = dual_code{[[
      user\update {
        views_count: db.raw "views_count + 1"
      }, timestamp: false
    ]]}
  }
}

### `delete()`

Attempts to delete the row backed by the model instance based on the primary
key.

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

`delete` will return `true` if the row was actually deleted. It's important to
check this value to avoid any race conditions when running code in response to a
delete.

Consider the following code:

```lua
local user = Users:find()

-- Wrong:
if user then
  user:delete()
  decrement_total_user_count()
end

-- Correct:
if user then
  if user:delete() then
    decrement_total_user_count()
  end
end
```

```moon
user = Users\find 1

-- Wrong:
if user
  user\delete!
  decrement_total_user_count!

-- Correct:
if user
  if user\delete!
    decrement_total_user_count!
```

Due to the asynchronous nature of OpenResty, it's possible that if two requests
enter this block of code around the same time `delete` may end up getting called
twice. This isn't a problem by itself, but the `decrement_total_user_count`
function would get called twice and may invalidate whatever data it has.

### `refresh(...)`

Updates the values of the fields on the instance from the database.

If your model instance becomes out of date from an external change, use the
`refresh` method to re-fetch and re-populate its data.

If the row now longer exists in the database, then `refresh` will throw an
error.

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

## Timestamps

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

You might create a table with timestamps using the schema syntax from Lapis
like this:

```lua
local schema = require "lapis.db.schema"

scehma.create_table("some_table", {
  -- ...
  {"created_at", schema.types.time},
  {"updated_at", schema.types.time}
  -- ...
})
```

```moon
import types, create_table from require "lapis.db.schema"

create_table "some_table", {
  -- ...
  {"created_at", types.time}
  {"updated_at", types.time}
  -- ...
}
```


You'll notice both columns are stored without timezone. Lapis stored
`created_at` and `updated_at` in UTC time.


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

## Constraints

Often before we insert or update a row we want to check that some conditions
are met. In Lapis these are called constraints. For example let's say we have a
user model and users are not allowed to have the name "admin".

We might define it like this:

```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  constraints = {
    name = function(self, value)
      if value:lower() == "admin" then
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
import Model from require "lapis.db.model"

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

## Pagination

Using the `paginated` method on models we can easily paginate through a query
that might otherwise return many results. The arguments are the same as the
`select` method but instead of the result it returns a special `Paginator`
object.

For example, say we have the following table and model: (See [Database Schemas](database.html#database-schemas) for more information on creating tables.)

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

The type of paginator created by the `paginated` class method is an
`OffsetPaginator`. This paginator uses `LIMIT` and `OFFSET` query clauses to
fetch pages. There is also an `OrderedPaginator` which is described below. It
can provide significantly increased performance for larger datasets given the
right indexes and circumstances are met.

> Always provide an `ORDER BY` clause when using a paginator or the pages
> returned by the paginator may not be consistent.

A paginator can be configured by passing a table as the last argument. The
following options are available for all types of paginators:

$options_table{
  {
    name = "per_page",
    description = "The number of items fetched per page",
    default = "`10`",
    example = dual_code{[[
      pager = Users\paginated "where group_id = ?", 4, per_page: 100
    ]]}
  },
  {
    name = "prepare_results",
    description = [[
      A function that is passed the results of any fetched page to prepare the objects before being retuned from methods like `get_page`, `get_all`, and `each_item`. It should return the results after they have been prepared or updated.

      This is useful for preloading related data automatically when fetching results to avoid the [n+1 queries problem](https://leafo.net/guides/postgresql-preloading.html).
    ]],
    example = dual_code{[[
      items = Posts\paginated "where category = ?", "big_cats", {
        per_page: 10
        prepare_results: (posts) ->
          Users\include_in posts, "user_id"
          posts
      }
    ]]}
  },
  {
    name = "...",
    description = "Any additional options are passed directly to the `select` class method to control the query. For example, `fields` can be used to restrict what columns are fetched"
  }
}

A paginator has the following methods:

### `get_page(page_num)`

Gets `page_num`th page, where pages are 1 indexed. The number of items per page
is controlled by the `per_page` option, and defaults to 10. Returns an array
table of model instances.

$dual_code{[[
page1 = paginated\get_page 1
page6 = paginated\get_page 6
]]}

```sql
SELECT * from "users" where group_id = 123 order by name asc limit 10 offset 0
SELECT * from "users" where group_id = 123 order by name asc limit 10 offset 50
```

> The OrderedPaginator fetches pages in a fundamentally different way, see
> below for more information.

### `num_pages()`

Returns the total number of pages.

### `total_items()`

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

### `each_page(starting_page=1)`

Returns an iterator function that can be used to iterate through each page of
the results. Useful for processing a large query without having the entire
result set loaded in memory at once.

Each item is preloaded with the `prepare_results` function if provided.

```lua
for page_results, page_num in paginated:each_page() do
  print(page_results, page_num)
end
```

```moon
for page_results, page_num in paginated\each_page!
  print(page_results, page_num)
```

> Be careful modifying rows in the database when iterating over each page, as
> your modifications might change the query result order and you may process
> rows multiple times or none at all. Consider using a stable sorting
> direction like the primary key ascending.

### `each_item()`

Returns an iterator for every item retuned by the pager. It uses `each_page` to
fetch results in chunks of `per_page` items. Because data is pulled
incrementally it's suitable for iterating over large data sets.

Each item is preloaded with the `prepare_results` function if provided.

> Iteration order can change if the table is modified during iteration, see the
> warning on `each_page`.

$dual_code{[[
for item in pager\each_item!
  print item.name
]]}

### `has_items()`

Checks to see if the paginator returns at least 1 item. Returns a boolean. This is
more efficient than counting the items and checking for a number greater than 0
because the query generated by this function doesn't do any counting.

```lua
if pager:has_items() then
  -- ...
end
```

```moon
if pager\has_items!
  do_something!
```

```sql
SELECT 1 FROM "users" where group_id = 123 limit 1
```

### `get_all()`

Gets every item from the paginator by issuing a single query, ignoring any pagination options.
If you have a large dataset you want to iterate over, consider using
`each_item` as it will query in chunks to reduce peak memory usage.

Each item is preloaded with the `prepare_results` function if provided.

$dual_code{[[
users = paginated\get_all!
]]}


```sql
SELECT * from "users" where group_id = 123 order by name asc
```

## Ordered Paginator

The default paginator, also know as the `OffsetPaginator`, uses `LIMIT` and
`OFFSET` to handle fetching pages. For large data sets, this can become
inefficient for viewing later pages since the database has to scan past all the
preceding rows when handling the offset.

An alternative way to handling pagination is using a `WHERE` clause along with
an `ORDER` and `LIMIT`. If the right index is on the table then the database
can skip directly to the rows that should be contained in the page.

With this method you don't get page numbers, but instead must keep track of the
last index of the previous page. This is best represented with a *load more*
button on your site.

The `OrderedPaginator` class is a subclass of the `Paginator` that uses this
method to paginate results.

Here's an example model:

```lua
create_table("events", {
  { "id", types.serial },
  { "user_id", types.foreign_key },
  { "data", types.text },

  "PRIMARY KEY(id)"
})

local Events = Model:extend("events")
```

```moon
create_table "events", {
  { "id", types.serial }
  { "user_id", types.foreign_key }
  { "data", types.text }

  "PRIMARY KEY(id)"
}

class Events extends Model
```

Here's how to instantiate an ordered paginator that can iterate over the `events`
table for a specific user id, in ascending order:

```lua
local OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
local pager = OrderedPaginator(Events, "id", "where user_id = ?", 123, {
  per_page = 50
})
```

```moon
import OrderedPaginator from require "lapis.db.pagination"
pager = OrderedPaginator Events, "id", "where user_id = ?", 123, {
  per_page: 50
}
```

The `OrderedPaginator` constructor function matches the same interface as the
regular `Paginator` except it takes an additional argument after the model name:
the name of the column(s) to order by.

Call `get_page` with no arguments to get the first page of results. In addition
to the results of the query, the addition arguments contain the values that
should be passed to get page to get the next page of results.

```lua
-- get the first page
local results, next_page = pager:get_page()

-- get the next page
local results_2, next_page = pager:get_page(next_page)
```

```moon
-- get the first page
results, next_page = pager\get_page!

-- get the next page
results_2, next_page = pager\get_page next_page
```

```sql
SELECT * from "events" where user_id = 123 order by "events"."id" ASC limit 50
SELECT * from "events" where "events"."id" > 4832 and (user_id = 123) order by "events"."id" ASC limit 50
```

### Pagination order

The pagination order can be specified by the `order` field in the options
table. The default is `asc`.

```lua
local OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
local pager = OrderedPaginator(Events, "id", "where user_id = ?", 123, {
  order = "desc",
})
```

```moon
import OrderedPaginator from require "lapis.db.pagination"
pager = OrderedPaginator Events, "id", "where user_id = ?", 123, {
  order: "desc"
}
```

This will affect any calls to `get_page` on the paginator.

Additionally, the `after` and `before` methods on the paginator let you fetch
results in a specific order. They both share the same interface as `get_page`,
but `after` will always fetch ascending, and `before` will always fetch
descending.


### Composite ordering

If you have a model that has a composite sorting key (made up of more than one
column), you can pass a table array as the ordering column:

```lua
local OrderedPaginator = require("lapis.db.pagination").OrderedPaginator
local pager = OrderedPaginator(SomeModel, {"user_id", "post_id"})
```

```moon
import OrderedPaginator from require "lapis.db.pagination"
pager = OrderedPaginator SomeModel, {"user_id", "post_id"}
```

The `get_page` method on the paginator takes as many arguments as there are
columns. Additionally, it will return that many additional values after the
results to be passed on as the next page


```lua
-- get the first page
local results, last_user_id, last_post_id = pager:get_page()

-- get the next page
local results_2 = pager:get_page(last_user_id, last_post_id)
```

```moon
-- get the first page
results, last_user_id, last_post_id = pager\get_page!

-- get the next page
results_2 = pager\get_page last_user_id, last_post_id
```

```sql
SELECT * from "some_model"
  order by "some_model"."user_id" ASC, "some_model"."post_id" ASC limit 10

SELECT * from "some_model" where
  ("some_model"."user_id", "some_model"."post_id") > (232, 582)
  order by "some_model"."user_id" ASC, "some_model"."post_id" ASC limit 10
```

## Relations

Often your models are connected to other models by use of a *foreign_key*. You
can describe the relationships between models using the `relations` class
property.

```lua
local Model = require("lapis.db.model").Model
local Posts = Model:extend("posts", {
  relations = {
    {"users", belongs_to = "Users"},
    {"posts", has_many = "Tags"}
  }
})
```

```moon
import Model from require "lapis.db.model"
class Posts extends Model
  @relations: {
    {"user", belongs_to: "Users"}
    {"posts", has_many: "Tags"}
  }
```

Lapis will automatically add a handful of methods for each relation to the
model class to make fetching the associated row easy.  For example the
`belongs_to` relation from the example above would make a `get_user` method:

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

The following relations are available:

### `belongs_to`

A relation that fetches a single related model. The foreign key column used to
fetch the other model is located on the same table as the model.

The name of the relation is used to derive the name of the column used as the
foreign key in addition to the name of the method added to the model to fetch
the associated row.

A `belongs_to` relation named `user` would look for a column named `user_id` on
the current model. When the relation is fetched, it will be cached in a field
named `user` in the model.


```lua
local Model = require("lapis.db.model").Model

local Posts = Model:extend("posts", {
  relations = {
    {"user", belongs_to = "Users"}
  }
})
```

```moon
import Model from require "lapis.db.model"

class Posts extends Model
  @relations: {
    {"user", belongs_to: "Users"}
  }
```

A `get_` method is added to the model to fetch the associated row:

$dual_code{[[
user = post\get_user!
]]}


```sql
SELECT * from "users" where "user_id" = 123;
```

The relation definition can take an optional `key` option to override what
field is used on the current model to reference as the foreign key.

If the relation returns `nil` from the database, then that will be cached on
the model and subsequent calls will return `nil` without issuing another query.
You can call the `refresh` method to clear the relation caches.

A variation of the `belongs_to` relation is
[`polymorphic_belongs_to`](#relations/polymorphic-belongs-to), which lets a
relation point to one of many different models.

### `has_one`

A relation that fetches a single related model. Similar to `belongs_to`, but
the foreign key used to fetch the other model is located on the other table.


```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  relations = {
    {"user_profile", has_one = "UserProfiles"}
  }
})
```

```moon
import Model from require "lapis.db.model"
class Users extends Model
  @relations: {
    {"user_profile", has_one: "UserProfiles"}
  }
```

A `get_` method is added to the model to fetch the associated row:

```lua
local profile = user:get_user_profile()
```

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

```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  relations = {
    {"user_profile", has_one = "UserProfiles", key = "owner_id"}
  }
})
```

```moon
import Model from require "lapis.db.model"

class Users extends Model
  @relations: {
    {"user_profile", has_one: "UserProfiles", key: "owner_id"}
  }
```

```lua
local profile = user:get_user_profile()
```

```moon
profile = user\get_user_profile!
```

```sql
SELECT * from "user_profiles" where "owner_id" = 123;
```

If the relation returns `nil` from the database, then that will be cached on
the model and subsequent calls will return `nil` without issuing another query.
You can call the `refresh` method to clear the relation caches.

### `has_many`

A one to many relation. It defines two methods, one that returns a [paginator
object](#pagination), and one that fetches all of the objects. In the following
example we create a model, Users, where each user can have many Posts
that they own:


```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  relations = {
    {"posts", has_many = "Posts"}
  }
})
```

In the above example, the `Users` model will expect that the table backed by
the `Posts` model contains a column `user_id` that will be used to find the
associated posts for each user.


The following options may be included to customize the relation

$options_table{
  {
    name = "key",
    description = [[
      The foreign key to search on. Either a string for singular foreign key,
      an array table to specify composite foreign keys, or a key-value table to
      specify cross-table column mapping.

      Defaults a singular foreign key by appending `_id` to the singular form of the table name, eg. `Users` → `user_id`
    ]],
    default = "`#{singular(table_name)}_id`"
  },
  {
    name = "where",
    description = "Set additional constraints on the things returned, as a table",
    example = [[
      ```lua
      local Model = require("lapis.db.model").Model

      local Users = Model:extend("users", {
        relations = {
          {"authored_posts",
            has_many = "Posts",
            where = { deleted = false }
          }
        }
      })
      ```

      ```moon
      import Model from require "lapis.db.model"
      class Users extends Model
        @relations: {
          {"authored_posts"
            has_many: "Posts"
            where: { deleted: false }
          }
        }
      ```
    ]]
  },
  {
    name = "order",
    description = "A SQL fragment as a string used to specify a default `order by` clause when the relation is fetched"
  },
  {
    name = "as",
    description = "Override the name included in the generated methods, and the cached object",
    default = "*relation name*"
  }
}


```moon
import Model from require "lapis.db.model"
class Users extends Model
  @relations: {
    {"posts", has_many: "Posts"}
  }
```

The following methods are added to the model for the `posts` relation shown above:

* `get_posts()` (`get_X`) -- fetch all the objects for that relation
* `get_posts_paginated(opts)` (`get_X_paginated`) -- return a pagination object for iterating through all the posts

We can use the `get_` method to fetch all the associated records. If the
relation has already been fetched then it will return the cached value. The
cached value is stored in a field on the model that matches the name of the
relation.

```lua
local posts = user:get_posts()
```

```moon
posts = user\get_posts!
```

```sql
SELECT * from "posts" where "user_id" = 123
```

The `get_X_paginated` method will return a [paginator](#pagination) for
iterating through the related objects. This is useful if you know the relation
could include a large number of things and it does not make sense to fetch them
all at once.

> It is highly recommended that you either specify and order in the relation,
> or use the ordered paginator otherwise the database may return items out of
> order when iterating over the pages of results. This could cause you see
> duplicate items or skip items entirely.

Any arguments passed to the `get_X_paginated` method are passed to the
paginator's constructor, so you can specify things like `fields`,
`prepare_results`, and `per_page`:


$dual_code{[[
posts = user\get_posts_paginated(per_page: 20)\get_page 3
]]}

```sql
SELECT * from "posts" where "user_id" = 123 LIMIT 20 OFFSET 40
```

By default, an `OffsetPaginator` (paginated with `LIMIT` and `OFFSET`) is
created. If you want to use the [OrderedPaginator](#ordered-paginator) you can
specify an `ordered` option to the method with a list:

$dual_code{[[
pager = user\get_posts_paginated per_page: 20, ordered: {"id"}

posts, next_page = pager\get_page!
posts2 = pager\get_page next_page
]]}

```sql
SELECT * from "posts" where "user_id" = 123 ORDER BY "posts"."id" ASC LIMIT 20
SELECT * from "posts" where "posts".id > 23892 and ("user_id" = 123)
  ORDER BY "posts"."id" ASC LIMIT 20
```

Here's a more complex example utilizing some of the options for `has_many`:

```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  relations = {
    {"authored_posts",
      has_many = "Posts",
      where = {deleted = false},
      order = "id desc",
      key = "poster_id"}
  }
})
```

```moon
import Model from require "lapis.db.model"
class Users extends Model
  @relations: {
    {"authored_posts"
      has_many: "Posts"
      where: {deleted: false}
      order: "id desc"
      key: "poster_id"}
  }
```

```lua
local posts = user:get_authored_posts()
```

```moon
posts = user\get_authored_posts!
```

```sql
SELECT * from "posts" where "poster_id" = 123 and deleted = FALSE order by id desc
```

### `fetch`

A manual relation where you provide a function that will fetch the associated
data for an individual row. A preload implementation can also be provided.
Lapis will automatically cache the result of the fetch like it does with the
other relation types.

```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  relations = {
    {"recent_posts", fetch = function()
      -- fetch some data
    end}
  }
})
```

```moon
import Model from require "lapis.db.model"
class Users extends Model
  @relations: {
    {"recent_posts", fetch: =>
      -- fetch some data
    }
  }
```

The following options control how the `fetch` relation works:

$options_table{
  {
    name = "fetch",
    description = "Callback function to fetch a result for a single model instance, or the value `true` to use the `preload` function to load a single result",
    default = "***required***"
  },
  {
    name = "preload",
    description = "Callback function to load data for many model instances at once. Receives an argument of an array of model instances, and more. This is only required if trying to preload multiple objects at once, or when using fetch set to `true`. See below"
  },
  {
    name = "many",
    description = "Set this to true if your fetch relation returns a collection of models instead of a single model. This will allow the preloader to traverse arrays of objects loaded with fetch",
    default = "`false`"
  }
}

A preload function can be provided to bulk load data for many objects at once.
It is automatically called when using any of Lapis' preload functions. The
`preload` function receives four arguments:

* an array table of model instances that should be preloaded
* any options passed to the original call to `preload`
* the class of the model
* the name of the relation

The `preload` function is responsible for setting the loaded value on each
object. The `name` argument is the name of the field that should be filled for
each instance.  All of the instances will be marked as having the relation
loaded, regardless of if you set a value or not. This means that future calls
to `get_` will return the cached value.

To simplify writting getters, `fetch` can be set to `true` to autogenerate a
function based on the `preload` function when getting the associated value from
a single instance of the model.

```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  relations = {
    {"recent_posts",
      -- we can use true here to have the singular getter automatically
      -- generated based on the preload function
      fetch = true,
      preload = function(objs)
        for object in pairs(objs) do
          -- provide your own preload code and store the result on the object
          object.recent_posts = some_preloading_code(object)
        end
      end,
    }
  }
})
```

```moon
import Model from require "lapis.db.model"
class Users extends Model
  @relations: {
    {"recent_posts"
      -- we can use true here to have the singular getter automatically
      -- generated based on the preload function
      fetch: true
      preload: (objs) ->
        for object in *objs
          -- provide your own preload code and store the result on the object
          object.recent_posts = some_preloading_code object
    }
  }
```


### `polymorphic_belongs_to`

A relation that fetches a single related model that can be one of multiple
models. For example, you might have a `Purchases` model that is associated with
the object that was bought, which could be one of many types: `VideoGames`,
`Books`. The related models are fetched up by their primary key.

The type of the related object is stored in an [`enum` field](#enum)
automatically created during relation initialization. The `enum` is named after
the type of the relation, suffixed with `_type`. The string values in the
`enum` are the names of the tables.

The syntax for creating a `polymorphic_belongs_to` takes the type's id with the
name of the model class it points to. Integers are used to represent types.
Just like `enum`, it's recommended to explicitly write the integer keys to make
it clear that they can't be reordered without changing the meaning of the
relation.


```lua
local Model = require("lapis.db.model").Model

local Purchases = Model:extend("purchases", {
  relations = {
    {"object", polymorphic_belongs_to = {
      [1] = "Users",
      [2] = "Books",
    }},
  }
})
```

```moon
import Model from require "lapis.db.model"

class Posts extends Model
  @relations: {
    {"user", polymorphic_belongs_to: {
      [1]: "Users"
      [2]: "Books"
    }}
  }
```

In the example above, an `enum` named `object_types` is created. Note that is
uses the table names, instead of the class names. It is equivalent to:


```lua
Purchases.object_types = enum {
  users = 1,
  books = 2
}
```

```moon
Purchases.object_types = enum {
  users: 1
  books: 2
}
```

The following methods are automatically generated on the model class with the
polymorphic relation: (where `#{name}` is the name of the relation)

* `model_for_#{name}_type(type)` -- Takes the integer or name from type `enum` and returns the model class associated to that type. If the class could not be found an error is raised
* `#{name}_type_for_model(model)` -- Takes a model and returns the `enum` type for it (as integer)
* `#{name}_type_for_object(obj)` -- Takes an instances of an object and returns the `enum` type for it (as integer)


A *getter* instance method is added to the model:

* `get_#{name}` -- Will fetch and return the associated object. This will only perform a query if the relation has not already been fetched or preloaded. `nil` will be returned if no object could be found, or the foreign key is `nil`

Additionally, a preloader is installed into the model that will allow all
associated objects across all the different tables to be loaded efficiently.

#### Migrating for a New Polymorphic Relation

When adding a `polymorphic_belongs_to` to one of your tables you need to make
the appropriate columns. You'll need to create a foreign key column along with
the type column. The type column can use the built-in schema type `enum`.

The column names are named after the relation. For example, if your relation is
called `primary_item`, columns should be created with the names
`primary_item_id` and `primary_item_type`.


```lua
local schema = require("lapis.db.schema")

return {
  [1368686109] = function()
    schema.add_column("purchases", "primary_item_id", schema.types.foreign_key)
    schema.add_column("purchases", "primary_item_type", schema.types.enum)
  end,
}
```

```moon
import add_column, create_index, types from require "lapis.db.schema"

{
  [1368686109]: =>
    add_column "purchases", "primary_item_id", types.foreign_key
    add_column "purchases", "primary_item_type", types.enum
}
```

## Preloading relations

In addition to the method to fetch the associated rows on a single model
instance, relations also provide a way to preload the rows for many instances
of the model.

A common pitfall when using object relational mapping systems is triggering
many queries inside of a loop when fetching a related object on each iteration.
In order to avoid the `n+1` query problem you can load all the related models
ahead of time in a single query before iterating over them.

### `preload(instances, relations...)`


```lua
local preload = require("lapis.db.model").preload
```

```moon
import preload from require "lapis.db.model"
```

The `preload` function is a general purpose preloading for loading relations on
model instances. The first argument is an array of instances, and all other
arguments are the names of the relations to load.

You can also preload nested relations by using the hash table syntax:

```lua
preload(posts, {user = "twitter_account"})
```

```moon
preload posts, user: "twitter_account"
```

The hash table syntax can be combined with regular relation names as strings,
letting you preload complex sets of data in a single line. In the examples
above, the `user` relation is loaded on the posts, then every user has the
`twitter_account` relation loaded.

### `Model:preload_relation(instances, name, ...)`

> This function should be avoided in favor of the `preload` function when
> possible. If you need to pass parameters to a preload call then you need to
> use `preload_relation`

The class method `preload_relation` takes an array table of instances of the
model, and the name of a relation. It fills all the instances with the
associated models with a single query.

Internally this method called the `include_in` method. Any additional arguments
passed to `preload_relation` are merged in the options to the call to
`include_in`.


```lua
local Model = require("lapis.db.model").Model

local Posts = Model:extend("posts", {
  relations = {
    {"user", belongs_to = "Users"}
  }
})
```

```moon
import Model from require "lapis.db.model"

class Posts extends Model
  @relations: {
    {"user", belongs_to: "Users"}
  }
```

A `get_` method is added to the model to fetch the associated row:

```lua
local posts = Posts:select() -- select all the posts
-- load the user on all the posts
Posts:preload_relation(posts, "user")
```

```moon
posts = Posts\select! -- select all the posts
-- load the user for all the posts
Posts\preload_relation posts, "user"
```

```sql
SELECT * from "users" where "id" in (3,4,5,6,7);
```

### `Model:preload_relations(instances, names...)`

> This call is deprecated, use the `preload` function to preload many relations
> in a single call

`preload_relations` is a helper method for calling `preload_relation` many
times with different relations. This form does not support passing any options
to the preloaders. You should replace `Model` with the model that contains the
relation definition.

```lua
-- load three separate relations
Posts:preload_relations(posts, "user", "tags", "category")
```

```moon
-- load three separate relations
Posts\preload_relations posts, "user", "tags", "category"
```

## Enum

The `enum` function lets you create a special table that lets you convert
between integer constants and names. This is useful for creating enumerations in
your database rows by using integers to represent a state.

```lua
local model = require("lapis.db.model")
local Model, enum = model.Model, model.enum

local Posts = Model:extend("posts")
Posts.statuses = enum {
  pending = 1,
  public = 2,
  private = 3,
  deleted = 4
}
```

```moon
import Model, enum from require "lapis.db.model"

class Posts extends Model
  @statuses: enum {
    pending: 1
    public: 2
    private: 3
    deleted: 4
  }
```

```lua
assert(Posts.statuses[1] == "pending")
assert(Posts.statuses[3] == "private")

assert(Posts.statuses.public == 2)
assert(Posts.statuses.deleted == 4)

assert(Posts.statuses:for_db("private") == 3)
assert(Posts.statuses:for_db(3) == 3)

assert(Posts.statuses:to_name(1) == "pending")
assert(Posts.statuses:to_name("pending") == "pending")

-- using to_name or for_db with undefined enum value throws error

Posts.statuses:to_name(232) -- error
Posts.statuses:for_db("hello") -- error
```

```moon
assert Posts.statuses[1] == "pending"
assert Posts.statuses[3] == "private"

assert Posts.statuses.public == 2
assert Posts.statuses.deleted == 4

assert Posts.statuses\for_db("private") == 3
assert Posts.statuses\for_db(3) == 3

assert Posts.statuses\to_name(1) == "pending"
assert Posts.statuses\to_name("pending") == "pending"

-- using to_name or for_db with undefined enum value throws error

Posts.statuses\to_name 232 -- error
Posts.statuses\for_db "hello" -- error

```

