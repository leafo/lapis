{
  title: "Database Access"
}
# Database Access

Lapis comes with a set of classes and functions for working with either
[PostgreSQL](http://www.postgresql.org/) or [MySQL](https://www.mysql.com/). In
the future other databases will be directly supported. In the meantime, you're
free to use other OpenResty database drivers, you just won't have access to
Lapis' query API.

Every query is performed asynchronously through the [OpenResty cosocket
API](http://wiki.nginx.org/HttpLuaModule#ngx.socket.tcp). A request will yield
and resume automatically so there's no need to code with callbacks, queries can
be written sequentially as if they were in a synchronous environment. Additionally
connections to the server are automatically pooled for optimal performance.

Depending on which database you use, a different library is used:

[pgmoon](https://github.com/leafo/pgmoon) is the driver used to run
PostgreSQL queries. It has the advantage of being able to be used within
OpenResty's cosocket API in addition to on the command line using LuaSocket's
synchronous API.

When in the context of the server,
[lua-resty-mysql](https://github.com/openresty/lua-resty-mysql) is the driver
used to run MySQL queries. When on the command line,
[LuaSQL](http://keplerproject.github.io/luasql/doc/us/) with MySQL is used.

## Establishing A Connection

You'll need to configure Lapis so it can connect to the database.

### PostgreSQL

If you're using PostgreSQL create a `postgres` block in our <span
class="for_moon">`config.moon`</span><span class="for_lua">`config.lua`</span>
file.

```lua
-- config.lua
local config = require("lapis.config")
config("development", {
  postgres = {
    host = "127.0.0.1",
    user = "pg_user",
    password = "the_password",
    database = "my_database"
  }
})
```

```moon
-- config.moon
import config from require "lapis.config"
config "development", ->
  postgres ->
    host "127.0.0.1"
    user "pg_user"
    password "the_password"
    database "my_database"
```

`host` defaults to `127.0.0.1` and `user` defaults to `postgres`, so you can
leave those fields out if they aren't different from the defaults. If a
non-default port is required it can be appended to the `host` with colon
syntax: `my_host:1234` (Otherwise `5432`, the PostgreSQL default, is used).

### MySQL

If you're using MySQL the approach is similar, but you will define a `mysql`
block:

```lua
-- config.lua
local config = require("lapis.config")
config("development", {
  mysql = {
    host = "127.0.0.1",
    user = "mysql_user",
    password = "the_password",
    database = "my_database"
  }
})
```

```moon
-- config.moon
import config from require "lapis.config"
config "development", ->
  mysql ->
    host "127.0.0.1"
    user "mysql_user"
    password "the_password"
    database "my_database"
```

You're now ready to start making queries.

## Making a Query

There are two ways to make queries:

1. The raw query interface is a collection of functions to help you write SQL.
1. The [`Model` class](models.html) is a wrapper around a Lua table that helps you synchronize it with a row in a database table.

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

return app
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

return app
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
the message from the database along with the query.

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

> `RETURNING` is a PostgreSQL feature, and is not available when using MySQL

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

When using the table form for conditions, all the extra arguments are used for
the `RETURNING` clause:

```lua
db.update("cats", {
  count = db.raw("count + 1")
}, {
  id = 1200
}, "count")
```

```moon
db.update "cats", {
  count: db.raw "count + 1"
}, {
  id: 1200
}, "count"
```

```sql
UPDATE "cats" SET "count" = count + 1, WHERE "id" = 1200 RETURNING count
```

> `RETURNING` is a PostgreSQL feature, and is not available when using MySQL

### `delete(table, conditions, params...)`

Deletes rows from `table` that match `conditions`.

```lua
db.delete("cats", { name = "Roo" })
```

```moon
db.delete "cats", name: "Roo"
```

```sql
DELETE FROM "cats" WHERE "name" = 'Roo'
```

`conditions` can also be a string

```lua
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

### `list({values...})`

Returns a special value that will be inserted into the query using SQL's list
syntax. It takes a single argument of an array table.

The return value of this function can be used in place of any regular value
passed to a SQL query function. Each item in the list will be escaped with
`escape_literal` before being inserted into the query.

Note we can use it both in interpolation and in the clause to a `db.update`
call:

```lua
local ids = db.list({3,2,1,5})
local res = db.select("* from another table where id in ?", ids)

db.update("the_table", {
  height = 55
}, {
  id = ids
})
```

```moon
ids = db.list {3,2,1,5}
res = db.select "* from another table where id in ?", ids

db.update "the_table", {
  height: 55
}, { :ids }
```

```sql
SELECT * from another table where id in (3, 2, 1, 5)
UPDATE "the_table" SET "height" = 55 WHERE "ids" IN (3, 2, 1, 5)
```

### `array({values...})`

Converts the argument passed to an array type that will be inserted/updated
using PostgreSQL's array syntax. This function does not exist for MySQL.

The return value of this function can be used in place of any regular value
passed to a SQL query function. Each item in the list will be escaped with
`escape_literal` before being inserted into the query.

The argument is converted, not copied. If you need to avoid modifying the
argument then create a copy before passing it to this function.


```lua
db.insert("some_table", {
  tags = db.array({"hello", "world"})
})
```

```moon
db.insert "some_table", {
  tags: db.array {"hello", "world"}
}
```

```sql
INSERT INTO "some_table" ("tags") VALUES (ARRAY['hello','world'])
```

### `escape_literal(value)`

Escapes a value for use in a query. A value is any type that can be stored in a
column. Numbers, strings, and booleans will be escaped accordingly.

```lua
local escaped = db.escape_literal(value)
local res = db.query("select * from hello where id = " .. escaped)
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

#### `interpolate_query(query, ...)`

Interpolates a query containing `?` markers with the rest of the
arguments escaped via `escape_literal`.

```lua
local q = "select * from table"
q = q .. db.interpolate_query("where value = ?", 42)
local res = db.query(q)
```

```moon
q = "select * from table"
q ..= db.interpolate_query "where value = ?", 42
res = db.query q
```

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

> In MySQL you should use `types.id` to get an autoincrementing primary key ID.
> Additionally you should not specify `PRIMARY KEY (id)` either.

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
name and columns. This is the same as the default index name generated by
database on creation.

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

print(types.boolean)       --> boolean NOT NULL DEFAULT FALSE
print(types.date)          --> date NOT NULL
print(types.double)        --> double precision NOT NULL DEFAULT 0
print(types.foreign_key)   --> integer NOT NULL
print(types.integer)       --> integer NOT NULL DEFAULT 0
print(types.numeric)       --> numeric NOT NULL DEFAULT 0
print(types.real)          --> real NOT NULL DEFAULT 0
print(types.serial)        --> serial NOT NULL
print(types.text)          --> text NOT NULL
print(types.time)          --> timestamp without time zone NOT NULL
print(types.varchar)       --> character varying(255) NOT NULL
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
* `array: bool|number` -- makes the type an array (PostgreSQL Only), pass number to set how many dimensions the array is, `true` == `1`

Here are some examples:

```lua
types.integer({ default = 1, null = true })  --> integer DEFAULT 1
types.integer({ primary_key = true })        --> integer NOT NULL DEFAULT 0 PRIMARY KEY
types.text({ null = true })                  --> text
types.varchar({ primary_key = true })        --> character varying(255) NOT NULL PRIMARY KEY
types.real({ array = true })                 --> real[]
```

```moon
types.integer default: 1, null: true  --> integer DEFAULT 1
types.integer primary_key: true       --> integer NOT NULL DEFAULT 0 PRIMARY KEY
types.text null: true                 --> text
types.varchar primary_key: true       --> character varying(255) NOT NULL PRIMARY KEY
types.real array: true                --> real[]
types.text array: 2                   --> real[][]
```

> MySQL has a complete different type set than PostgreSQL, see [MySQL
> types](https://github.com/leafo/lapis/blob/master/lapis/db/mysql/schema.moon#L162)

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

Read more about [the migrate command](command_line.html#command-reference/lapis-migrate).

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

## Database Helpers

These are additional helper functions from the `db` module that
aren't directly related to the query interface.

#### `format_date(time)`

Returns a date string formatted properly for insertion in the database.

The `time` argument is optional, will default to the current UTC time.

```lua
local date = db.format_date()
db.query("update things set published_at = ?", date)
```

```moon
date = db.format_date!
db.query "update things set published_at = ?", date
```

