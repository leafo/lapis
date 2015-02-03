
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


<p class="for_moon">
If you want to use a different table name you can overwrite the
<code>@table_name</code> class method:
</p>

```moon
class Users extends Model
  @table_name: => "active_users"
```

Model instances will have a field for each column that has been fetched from
the database. You do not need to manually specify the names of the columns.  If
you have any relationships, though, you can specify them using the
[`releations` property](#describing-relationships).

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

## Class Mehods

Model class methods are used for fetching existing rows or creating new ones.

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
local user = Users:find({ [db.raw("lower(email)")] = some_email\lower! })
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

The `fields` option is inserted into the SQL statement as is, so do not use
untrusted strings otherwise you may be vulnerable to SQL injection. Use
[`db.escape_identifier`](database.html#query-interface-escape_identifierstr) to
escape column names.

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

### `create(values, create_opts=nil)`

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

If any of the column values are
[`db.raw`](database.html#query-interface-rawstr) then their computed values
will also be fetched using the `RETURN` clause of the `CREATE` statement. The
raw values are replaced by the values returned by the database.

For example, we might create a new row in a table with a `position` column set
to the next highest number:

```moon
user = Users\create {
  position: db.raw "(select coalesce(max(position) + 1, 0) from users)"
}
```

```lua
local user = Users:create({
  position = db.raw("(select coalesce(max(position) + 1, 0) from users)"0
})
```

```sql
INSERT INTO "users" (position)
VALUES ((select coalesce(max(position) + 1, 0) from users))
RETURNING "id", "position"
```

If your model has any [constraints](#constraints) they will be checked before trying to create
a new row. If a constraint fails then `nil` and the error message are returned
from the `create` function.

`create` can take an options table as a second argument. It supports the
following options:

* `returning` -- A string containing a list of columns to fetch along with the create statement using the `RETURNING` statement

## Instance Methods

### `update(...)`

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
method](#class-mehods-createopts).


### `delete()`

To delete the row call `delete`.


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
  {"created_at", schema.types.time}
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

## Preloading Associations

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

`include_in` supports the following options, including `as` and `flip` from above:

* `as` -- set the name of the property to store the associated model as
* `flip` -- set to `true` if the named column is located on the included model
* `where` -- a table of additional conditionals to limit the query by
* `fields` -- set the fields returned by each included model

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

A paginator can be configured by passing a table as the last argument.
The following options are supported:

`per_page`: sets the number of items per page

```lua
local paginated2 = Users:paginated("where group_id = ?", 4, { per_page = 100 })
```

```moon
paginated2 = Users\paginated [[where group_id = ?]], 4, per_page: 100
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

Whenever possible you should specify an `ORDER` clause in your paginated query,
as the database might returned unexpected results for each page.

The paginator has the following methods:

### `get_all()`

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

### `get_page(page_num)`

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

```lua
for page_results, page_num in paginated:each_page() do
  print(page_results, page_num)
end
```

```moon
for page_results, page_num in paginated\each_page!
  print(page_results, page_num)
```

> Be careful modifying rows when iterating over each page, as your
> modifications might change the pagination order and you may process rows
> multiple times or none at all.

## Describing Relationships

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
import Model from require "lapis.db.models"
class Posts extends Model
  @relations: {
    {"user", belongs_to: "Users"}
    {"posts", has_many: "Tags"}
  }
```

Relations will automatically add methods to models to make fetching the
associated model instances easy. For example the `belongs_to` relation from the
example above would make a `get_user` method:


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

### `belongs_to`

A one-to-one relation where the foreign key is located on the current model.


```lua
local Model = require("lapis.db.model").Model

local Posts = Model:extend("posts", {
  relations = {
    {"user", belongs_to = "Users"}
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

Creates `get_` method for each relation.

```lua
local user = post:get_user()
```

```moon
user = post\get_user!
```

```sql
SELECT * from "users" where "user_id" = 123;
```

### `has_one`

A one-to-one relation where the foreign key is located on the associated model.

```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  relations = {
    {"user_profile", has_one = "UserProfiles"}
  }
})
```

```moon
import Model from require "lapis.db.models"
class Users extends Model
  @relations: {
    {"user_profile", has_one: "UserProfiles"}
  }
```

Creates `get_` method for each relation.

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
import Model from require "lapis.db.models"

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

### `has_many`

A one to many relation, returns a [`Pager` object](#pagination).

```lua
local Model = require("lapis.db.model").Model

local Users = Model:extend("users", {
  relations = {
    {"posts", has_many = "Posts"}
  }
})
```

```moon
import Model from require "lapis.db.models"
class Users extends Model
  @relations: {
    {"posts", has_many: "Posts"}
  }
```

```lua
local posts = user:get_posts({per_page = 20}):get_page(3)
```

```moon
local posts = user\get_posts(per_page: 20)\get_page 3
```

```sql
SELECT * from "posts" where "user_id" = 123 LIMIT 20 OFFSET 40
```

You can override the foreign key column name by passing a `key` relation
property.

### `fetch`

A custom relation, provide a function to fetch the associated data. Result is cached.

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
import Model from require "lapis.db.models"
class Users extends Model
  @relations: {
    {"recent_posts", fetch: =>
      -- fetch some data
    }
  }
```

## Inspecting Columns

You can get the column names and column types of a table using the `columns`
method on the model class:

```lua
local Posts = Model:extend("posts")
for _, col in ipairs(Posts:columns()) do
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

## Refreshing a Model Instance

If your model instance becomes out of date from an external change, it can tell
it to re-fetch and re-populate its data using the `refresh` method.

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

## Enum

The `enum` function lets you create a special table that lets you convert
between integer constants and names. This is useful for created enumerations in
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

Posts.statuses:to_name(232) -- erorr
Posts.statuses:for_db("hello") -- erorr
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

Posts.statuses\to_name 232 -- erorr
Posts.statuses\for_db "hello" -- erorr

```

