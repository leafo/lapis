{
  title: "Database Access"
}
# Database Access

Lapis comes with a set of classes and functions for working with either
[PostgreSQL](http://www.postgresql.org/), [MySQL](https://www.mysql.com/) or
[SQLite](http://https://sqlite.org/index.html).

In the supported environments, queries are performed asynchronously (eg.
[OpenResty cosocket API](http://wiki.nginx.org/HttpLuaModule#ngx.socket.tcp))
to allow for high throughput under heavy load. A request will yield and resume
automatically when issuing queries so there's no need to code with callbacks,
queries can be written sequentially as if they were in a synchronous
environment.

In supported environments, connection pooling will be used to ensure an optimal
number of connections are opened to depending on the concurrent load to your
application.

> Since SQL is embedded into your application, all queries are blocking and no connection pooling is used.

Depending on which database you use, a different library is used. You may need
to install these libraries manually if you wish the use the associated
database. (It is recommended to add supplemental dependencies of your
application to a local [rockspec
file](https://github.com/luarocks/luarocks/wiki/Rockspec-format).)

* **PostgreSQL:** [pgmoon](https://github.com/leafo/pgmoon). Supports a wide
  range of environments like OpenResty's cosocket API in addition LuaSocket and
  cqueues
* **MySQL:** When in the context of the OpenResty,
  [lua-resty-mysql](https://github.com/openresty/lua-resty-mysql) is used
  otherwise [LuaSQL-MySQL](https://lunarmodules.github.io/luasql/)
* **SQLite:** [LuaSQLite3](http://lua.sqlite.org/index.cgi/home)

## Database Modules

Lapis provides a collection of Lua modules for performing operations against
your database. The generic named modules will automatically select the
appropriate database specific module based on your application's configuration:

* `require("lapis.db")` -- Manages connection, `query`, `insert`, etc. functions
* `require("lapis.db.model")` -- The base class for Model classes backed by database tables & rows
* `require("lapis.db.schema")` -- Changing your database's schema, eg. creating tables, indexes, renaming, etc.

As an example, if your application is configured to PostgreSQL, then the
following three require statements above will actually load the following
modules: `lapis.db.postgres`, `lapis.db.postgres.model` and
`lapis.db.postgres.schema`.

The precedence for selecting a datbase is PostgreSQL, MySQL, SQLite. If you
have multiple database configurations then you will need to manually require
the module for the database you wish to use.

Additionally, the `lapis.db.migrations` module manages a table that keeps track
of schema changes (aka Migrations). This module will utilize the generic
`lapis.db` module, meaning it will use whatever database takes precedence in
your application's configuration. Learn more about [Database
Migrations](#database-migrations)

## Establishing A Connection

You'll need to configure Lapis so it can connect to the database. Lapis manages
a single global database connection (or pool of connections) in the `lapis.db`
module. It will ensure that you are using connections efficiently, and clean up
any resources automatically. When you first attempt to send a query, Lapis will
automatically prepare a connection for use. It is not necessary to manually
connect or disconnect to the database for standard use.

If you need multiple database connections in the same project then you will
have to manually create and release them.

### PostgreSQL

To use PostgreSQL create a `postgres` block in the <span
class="for_moon">`config.moon`</span><span class="for_lua">`config.lua`</span>
file.

$dual_code{
moon=[[
-- config.moon
import config from require "lapis.config"
config "development", ->
  postgres ->
    host "127.0.0.1"
    user "pg_user"
    password "the_password"
    database "my_database"
]],
lua=[[
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
]]}

`host` defaults to `127.0.0.1` and `user` defaults to `postgres`, so you can
leave those fields out if they aren't different from the defaults. If a
non-default port is required it can be appended to the `host` with colon
syntax: `my_host:1234` (Otherwise `5432`, the PostgreSQL default, is used).

### MySQL

To use MySQL create a `mysql` block in the <span
class="for_moon">`config.moon`</span><span class="for_lua">`config.lua`</span>
file.


$dual_code{
moon=[[
-- config.moon
import config from require "lapis.config"
config "development", ->
  mysql ->
    host "127.0.0.1"
    user "mysql_user"
    password "the_password"
    database "my_database"
]],
lua=[[
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
]]}

### SQLite

If you use the `lapis.db.sqlite` module then a database named
`lapis.sqlite` will be created in the working directory by default.
You can configure what database file to use like so:

$dual_code{
moon=[[
-- config.moon
import config from require "lapis.config"
config "development", ->
  sqlite ->
    database "my_database.sqlite"
    -- open_flags ...
]],
lua=[[
-- config.lua
local config = require("lapis.config")
config("development", {
  sqlite = {
    database = "my_database.sqlite",
    -- open_flags = ...
  }
})
]]
}

> You can use the specially named `":memory:"` database to have a temporary
> database that lives only for the duration of your apps runtime.

## Making a Query

There are generally two ways to work with the data in your database:

1. The `lapis.db` module is a collection of functions to make queries to the database, returning the reults as plain Lua tables.
1. The [`Model` class](models.html) is a wrapper around a Lua table that helps you synchronize it with a row in a database table. When appropriate, the results from the database are converted to instances of the model's class.

The `Model` class is the preferred way to interact with the database. Issuing
queries from the `lapis.db` module should preferred for achieving things the
`Model` class is unable to do easily.

Here's an example of how you might use the `query` function in the `lapis.db`
module to issue a query to the database:

$dual_code{
moon=[[
lapis = require "lapis"
db = require "lapis.db"

class extends lapis.Application
  "/": =>
    res = db.query "select * from my_table where id = ?", 10
    "ok!"
]],
lua=[[
local lapis = require("lapis")
local db = require("lapis.db")

local app = lapis.Application()

app:match("/", function()
  local res = db.query("select * from my_table where id = ?", 10)
  return "ok!"
end)

return app
]]}

And here's how you would accomplish something similar using `Model` class to
represent rows in a table:

$dual_code{
moon=[[
lapis = require "lapis"
import Model from require "lapis.db.model"

class MyTable extends Model

class extends lapis.Application
  "/": =>
    row = MyTable\find 10
    "ok!"
]],
lua=[[
local lapis = require("lapis")
local Model = require("lapis.db.model").Model

local app = lapis.Application()

local MyTable = Model:extend("my_table")

app:match("/", function()
  local row = MyTable:find(10)
  return "ok!"
end)

return app
]]}


By default all queries will log to the Nginx notice log. You'll be able to see
each query as it happens.

You can also issue queries in your command line scripts using the same
configuration, just require the model or `lapis.db` module and start using it.
Keep in mind that your configuration is loaded based on the working directory
of your project, so you should execute your scripts from the same directory as
your <span class="for_moon">`config.moon`</span><span
class="for_lua">`config.lua`</span> file so that you configuration can
be loaded.

## Query Interface

$dual_code{
moon=[[
db = require "lapis.db"
]],
lua=[[
local db = require("lapis.db")
]]}

The `db` module provides the following functions:

### `db.query(query, params...)`

Sends a query to the database using an active & available connection. If there
is no connection, then Lapis will automatically allocate & connect one using
the details provided in your configuration.

Returns the results as a Lua table if successful. Will throw an error if the
operation failed.

The first argument is the query to perform. If the query contains any `?`s then
they are replaced in the order they appear with the remaining arguments. The
remaining arguments are escaped with `escape_literal` before being
interpolated, making SQL injection impossible.

$dual_code{[[
res1 = db.query "SELECT * FROM hello"
res1 = db.query "SELECT * FROM users WHERE ?", db.clause {
  deleted: true
  status: "deleted"
}
res2 = db.query "UPDATE things SET color = ?", "blue"
res3 = db.query "INSERT INTO cats (age, name, alive) VALUES (?, ?, ?)", 25, "dogman", true
]]}

```sql
SELECT * FROM hello
SELECT * FROM users WHERE deleted AND status = 'deleted'
UPDATE things SET color = 'blue'
INSERT INTO cats (age, name, alive) VALUES (25, 'dogman', TRUE)
```

A query that fails to execute will raise a Lua error. The error will contain
the message from the database along with the query.

Every single function that Lapis provides which communicates with the database
will eventually end up calling `db.query`. The same logic with regards to error
handling and connection management applies to all database operations that
Lapis does.

### `db.select(query, params...)`

Similar to `db.query`, but it appends `"SELECT"` to the front of the query.

$dual_code{[[
res = db.select "* from hello where active = ?", false
]]}


```sql
SELECT * from hello where active = FALSE
```

### `db.insert(table, values, opts_or_returning...)`

Inserts a row into `table`. `values` is a Lua table of column names and values.

$dual_code{[[
db.insert "my_table", {
  age: 10
  name: "Hello World"
}
]]}

```sql
INSERT INTO "my_table" ("age", "name") VALUES (10, 'Hello World')
```

A list of column names to be returned can be given after the value table:

$dual_code{[[
res = db.insert "some_other_table", {
  name: "Hello World"
}, "id"
]]}

```sql
INSERT INTO "some_other_table" ("name") VALUES ('Hello World') RETURNING "id"
```

> `RETURNING` and `ON CONFLICT` are PostgreSQL feature, and not available when using MySQL

Alternatively, a options table can be provided as third argument with support
for the following fields: (When providing an options table, all other arguments
are ignored)

$options_table{
  {
    name = "returning",
    description = "An array table of column names or the string `'*'` to represent all column names. Their values will be return from the insertion query using `RETURNING` clause to initially populate the model object. `db.raw` can be used for more advanced expressions",
    example = dual_code{[[
      res = db.insert "my_table", { color: "blue" }, returning: "*"
      res = db.insert "my_table", {
        created_at: "2021-4-11 6:6:20"
      }, {
        returning: { db.raw "date_trunc('year', created_at) as create_year" }
      }
    ]]}
  },
  {
    name = "on_conflict",
    description = 'Control the `ON CONFLICT` clause for the insertion query. Currently only supports the string value `"do_nothing"` to do nothing when the query has a conflict',
    example = dual_code{[[
      res = db.insert("my_table", { color: "blue" }, on_conflict: "do_nothing")
    ]]}
  }
}


### `db.update(table, values, conditions, params...)`

Updates `table` with `values` on all rows that match `conditions`. If
conditions is a plain table or a `db.clause` object, then it will be converted
to SQL using `db.encode_clause`.

$dual_code{[[
db.update "the_table", {
  name: "Dogbert 2.0"
  active: true
}, {
  id: 100
  active: db.NULL
}
]]}


```sql
UPDATE "the_table" SET "name" = 'Dogbert 2.0', "active" = TRUE WHERE "id" = 100 and "active" IS NULL
```

The return value is a table containing the status of the update. The number of
rows updated can be determined by the `affected_rows` field of the returned
table.

`conditions` can also be a string, the remaining arguments will be interpolated
into the query as if you called `db.interpolate_query`.

$dual_code{[[
db.update "the_table", {
  count: db.raw"count + 1"
}, "count > ?", 10
]]}

```sql
UPDATE "the_table" SET "count" = count + 1 WHERE count > 10
```

When using a table or `db.clause` argument for conditions, all the extra
arguments are escaped as identifiers and appended as a `RETURNING` clause:

$dual_code{[[
db.update "cats", {
  count: db.raw "count + 1"
}, {
  id: 1200
}, "count"
]]}

```sql
UPDATE "cats" SET "count" = count + 1, WHERE "id" = 1200 RETURNING count
```

> You can use a `db.raw()` in place of the returning identifier name to
> evaluate a raw sql expression.

When using the returning clause the return value of `db.update` will be an
array of rows generated by the `RETURNING` expression, in addition to
containing the `affected_rows` field.

> `RETURNING` is a PostgreSQL feature, and is not available when using MySQL

### `db.delete(table, conditions, params...)`

Deletes rows from `table` that match `conditions`.

The `conditions` arugment can either be a Lua table mapping column to value, a
`db.clause`, or a string as a SQL fragment. When using the string condition,
the remaining arguments as passed as parameters to the SQL fragment as if you
called `db.interpolate_query`.

The return value is a table containing the status of the delete. The number of
rows deleted can be determined by the `affected_rows` field of the returned
table.

$dual_code{[[
db.delete "cats", name: "Roo"
db.delete "cats", "name = ? and age is null", "Gato"
]]}

```sql
DELETE FROM "cats" WHERE "name" = 'Roo'
DELETE FROM "cats" WHERE name = 'Gato' and age is null
```

When using a table argument for conditions, all the extra arguments are
escaped as identifiers and appended as a `RETURNING` clause:

$dual_code{[[
db.delete "cats", {
  id: 1200
}, "last_updated_at"
]]}


```sql
DELETE FROM "cats" WHERE "id" = 1200 RETURNING "last_updated_at"
```

> You can use a `db.raw()` in place of the returning identifier name to
> evaluate a raw sql expression.


The return value will now be an array of rows generated by the return values,
in addition to containing the `affected_rows` field.

> `RETURNING` is a PostgreSQL feature, and is not available when using MySQL


### `db.escape_literal(value)`

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

### `db.escape_identifier(str)`

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

### `db.interpolate_query(query, ...)`

Interpolates a query containing `?` markers with the rest of the arguments
escaped via `escape_literal`. If a `db.clause` is passed as one of the
arguments, then it will be encoded using `db.encode_clause`.

$dual_code{[[
q = db.interpolate_query "select * from table where value = ?", 42
res = db.query q

]]}


### `db.encode_clause(clause_obj)`

Generates a boolean SQL expression from an object describing one or many
conditions. The `clause` argument must be either a plain Lua table or a value
returned by `db.clause`.

If provided a plain table, then all key, value pairs are taken from the table
using `pairs`,and converted to an SQL fragment similar to
`db.escape_identifier(key) = db.escape_literal(value)`, then concatenated with
the `AND` SQL operator.

$dual_code{[[
print db.encode_clause {
  name: "Garf"
  color: db.list {"orange", "ginger"}
  processed_at: db.NULL
} --> "color" IN ('orange', 'ginger') AND "processed_at" IS NULL AND "name" = 'Garf'
]]}


If provided a `db.clause`, then a richer set of conditions can be described.
See the documentation for [`db.clause`](#database-primitives/clause)

`db.encode_clause` will throw an error on an empty clause. This is to prevent
the mistake of accidentally providing `nil` in place of a value of `db.NULL`
that results in generating a clause that matches a much wider range of data
than desired.

## Database Primitives

To make writing queries easier and safer, Lapis provides a set of basic
primitive types that can be used within your queries for constructing more
complicated values. Generally speaking, you should avoid interpolating data
directly into queries whenever possible as it creates the opportunity for SQL
injection attacks when values aren't properly encoded.

All database primitives constructors and values can be found on the `db`
module:

$dual_code{[[
db = require "lapis.db"
]]}



### `db.raw(str)`

Returns a an object wrapping the string argument that will be inserted verbatim
into a query without being escaped. Special care should be taken to avoid
generating invalid SQL and and to avoid introducing SQL injection attacks by
concatenated unsafe data into the string.

`db.raw` can be used inin almost any place where SQL query construction takes
place.  For example, `db.escape_literal` and `db.escape_identifier` will both
pass the string through unchanged. It can also be used in `db.encode_clause`
for both keys and values. You can use it where things like column names or
table names are also requested (eg. `db.update`)

$dual_code{[[
db.update "the_table", {
  count: db.raw"count + 1"
}

db.select "* from another_table where x = ?", db.raw"now()"
]]}

```sql
UPDATE "the_table" SET "count" = count + 1
SELECT * from another_table where x = now()
```

### `db.is_raw(obj)`

Returns `true` if `obj` is a value created by `db.raw`.

### `db.list({values...})`

Returns a special value that will be inserted into the query using SQL's list
syntax. It takes a single argument of an array table. A new object is returned
that wraps the original table. The original table is not modified.

The resulting object can be used in place of a value used within SQL query
generation with functions like `interpolate_query` and `encode_clause`. Each
item in the list will be escaped with `escape_literal` before being inserted
into the query.

Note how when it is used as a value for an SQL clause object, the `IN` syntax
is used.


$dual_code{[[
ids = db.list {3,2,1,5}
res = db.select "* from another table where id in ?", ids

db.update "the_table", {
  height: 55
}, { :ids }
]]}

### `db.is_list(obj)`

Returns `true` if `obj` is a value created by `db.list`.

### `db.clause({clause...}, opts?)`

Creates a *clause* object that can be encoded into a boolean SQL expression for
filtering or finding operations in the database. A clause object is an
encodable type that can be used in places like `db.encode_clause` and and
`db.interpolate_query` to safely generate an SQL fragment where all values are
escaped accordingly. Any built in Lapis functions that can take an object to
filter the affected rows can also take a clause object in place of a query
fragment or plain Lua table.

By default, a clause object will combine all paramters contained with the `AND`
operator.

When encoded to SQL, the clause object will attempt to extract filters from all
entries in the table:

* Key, value pairs in the hash-table portion of the clause table will be converted to a SQL fragment similar to `db.escape_identifier(key) = db.escape_literal(value)`. This mode is aware of booleans and `db.list` objects to generate the correct syntax
* Values in the array portion of the clause table will handled based on their type:
  * String values will be treated as raw SQL fragments that will be concatenated into the clause directly. All string values are warpped in `()` to ensure there are no precedence issues
  * Table values will passed to `interpolate_query` if the sub-table's first item is a string, eg. `{"views_count > ?", 100}`
  * A `nil` value will be skipped, meaning you can place conditionals directly inside of the clause
  * Clause objects can be nested by placing them in the array portion of the clause table

Here is an example demonstrating all the different ways of building out a clause:

$dual_code{[[
filter = db.clause {
  id: 12
  "username like '%admin'"
  deleted: false
  status: db.list {3,4}
  {"views_count > ?", 100}

  db.clause {
    active: true
    promoted: true
  }, operator: "OR"
}

res = db.query "SELECT * FROM profiles WHERE ?", filter
]]}

The following SQL will be generated:

```sql
SELECT * FROM profiles WHERE (username like '%admin') AND (views_count > 100) AND ("active" OR "promoted") AND "status" IN (3, 4) AND "id" = 12 AND not "deleted",
```

The second argument can be a table of options. The following properties are
supported:

$options_table{
  {
    name = "operator",
    description = [[
      Change the operator used to join the clause components. eg. `AND`, `OR`

    ]],
    example = dual_code{[[
      filter = db.clause {
         status: "deleted"
         deleted: true
      }, operator: "OR"

      print db.encode_clause filter --> "deleted" OR "status" = 'deleted'
    ]]},
    default = '`"AND"`'
  }, {
    name = "table_name",
    description = [[
      Prefixes each named field with the escaped table name. Note that this
      does not apply to SQL fragments in the clause. Sub-clauses are also not
      affected.
    ]],
    example = dual_code{[[
      filter = db.clause {
        color: "green"
        published: true
      }, table_name: "posts"

      print db.encode_clause filter --> "posts"."color" = 'green' AND "posts"."published"
    ]]}
  }, {
    name = "allow_empty",
    description = [[
      By default, an empty clause will throw an error when it is attampted to
      be encoded. This is to prevent you from accidentally filtering on
      something that has a nil value that should actually be provided. You must
      set this field to `true` in order to allow for the empty clause to be
      encoded into a query.
    ]],
    example = dual_code{moon=[[
      some_object = { the_id: 1 }

      -- This will throw an error to prevent you from accidentally deleting all
      -- rows because of an empty clause created by a nil value
      db.delete "users", db.clause {
        user_id: something.id -- oops, used the wrong field name and set this to nil
      }
    ]], lua=[[
      local some_object = { the_id = 1 }

      -- This will throw an error to prevent you from accidentally deleting all
      -- rows because of an empty clause created by a nil value
      db.delete("users", db.clause({
        user_id = something.id -- oops, used the wrong field name and set this to nil
      }))
    ]]}
  },{
    name = "prefix",
    description = [[
      Will append the string provied (separated by a space) to the front of the
      encoded result only if there is something in the table to be encoded.
      This can be combined with `allow_empty` to easily build optional `WHERE`
      clauses for queries

      > The string is inserted into the query fragment directly, avoid
      > untrusted input to avoid SQL injection.
    ]],
    example = dual_code{moon=[[
      db.encode_clause(db.clause({}, {prefix: "WHERE", allow_empty: true}) --> ""
      db.encode_clause(db.clause({id: 5}, {prefix: "WHERE", allow_empty: true}) --> [[WHERE "id" = 5]]

      db.query "SELECT FROM users ?", db.clause {
        -- if params.id is nil, then the clause will be encoded to empty string
        id: params.id 
      }, prefix: "WHERE", allow_empty: true
    ]], lua=[[
      db.encode_clause(db.clause({}, {prefix = "WHERE", allow_empty = true})) --> ""
      db.encode_clause(db.clause({id = 5}, {prefix = "WHERE", allow_empty = true})) --> [[WHERE "id" = 5]]

      db.query("SELECT FROM users ?", db.clause({
        -- if params.id is nil, then the clause will be encoded to empty string
        id = params.id
      }, { prefix = "WHERE", allow_empty = true }))
    ]]}
  }
}

### `db.is_clause(obj)`

Returns `true` if `obj` is a value created by `db.clause`.

### `db.array({values...})`

Converts the argument passed to an array type that will be inserted/updated
using PostgreSQL's array syntax. This function does not exist for MySQL.

The return value of this function can be used in place of any regular value
passed to a SQL query function. Each item in the list will be escaped with
`escape_literal` before being inserted into the query.

**Note:** This function mutates the object passed in by setting its metatable.
The returning object is the same value as the argument. This will allow the
object to still function as a regular Lua array. If you do not want to mutate
the argument, you must make a copy before passing it in.

Additionally, when a query returns an array from the database, it is
automatically converted into a `db.array`.

$dual_code{[[
db.insert "some_table", {
  tags: db.array {"hello", "world"}
}
]]}


```sql
INSERT INTO "some_table" ("tags") VALUES (ARRAY['hello','world'])
```

### `db.is_array(obj)`

Returns `true` if `obj` is a table with the `PostgresArray` metatable (eg. a
value created by `db.array`)

### `db.NULL`

Represents `NULL` in SQL syntax. In Lua, `nil` can't be stored in a table, so the
`db.NULL` object can be used to provide `NULL` as a value. When used with
`encode_clause`, the `IS NULL` syntax is automatically used.

$dual_code{[[
db.update "the_table", {
  name: db.NULL
}
]]}

```sql
UPDATE "the_table" SET name = NULL
```

### `db.TRUE`

Represents `TRUE` in SQL syntax. In most cases, it is not necessary to use this
constant, and instead the Lua boolean values can be used.

### `db.FALSE`

Represents `FALSE` in SQL syntax. In most cases, it is not necessary to use this
constant, and instead the Lua boolean values can be used.

## Database Schemas <span data-keywords="schema"></span>

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
print(types.enum)          --> smallint NOT NULL
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
types.enum          --> smallint NOT NULL
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
types.text array: 2                   --> text[][]
```

> MySQL has a complete different type set than PostgreSQL, see [MySQL types](https://github.com/leafo/lapis/blob/master/lapis/db/mysql/schema.moon#L162)

## Database Migrations

Because requirements typically change over the lifespan of a web application
it's useful to have a system to make incremental schema changes to the
database.

We define migrations in our code as a table of functions where the key of each
function in the table is the name of the migration. You are free to name the
migrations anything but it's suggested to give them Unix timestamps as names:

$dual_code{
moon=[[
import add_column, create_index, types from require "lapis.db.schema"

{
  [1368686109]: =>
    add_column "my_table", "hello", types.integer

  [1368686843]: =>
    create_index "my_table", "hello"
}
]],
lua=[[
local schema = require("lapis.db.schema")

return {
  [1368686109] = function()
    schema.add_column("my_table", "hello", schema.types.integer)
  end,

  [1368686843] = function()
    schema.create_index("my_table", "hello")
  end
}
]]}

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

#### `db.format_date(time)`

Returns a date string formatted properly for insertion in the database.

The `time` argument is optional, will default to the current UTC time.


$dual_code{[[
date = db.format_date!
db.query "update things set published_at = ?", date
]]}

