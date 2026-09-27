{
  title: "Lua Configuration Syntax"
}
<div class="override_lang" data-lang="lua"></div>

# Lua Configuration Syntax

## Configuration Example

Lapis' configuration module gives you support for merging tables recursively.

For example we might define a base configuration, then override some values in
the more specific configuration declarations:


```lua
-- config.lua
local config = require("lapis.config")

config({"development", "production"}, {
  host = "example.com",
  email_enabled = false,
  postgres = {
    host = "localhost",
    port = "5432",
    database = "my_app"
  }
})

config("production", {
  email_enabled = true,
  postgres = {
    database = "my_app_prod"
  }
})
```

This results in the following two configurations (default values omitted):

```lua
-- "development"
{
  host = "example.com",
  email_enabled = false,
  postgres = {
    host = "localhost",
    port = "5432",
    database = "my_app",
  },
  _name = "development"
}
```

```lua
-- "production"

{
  host = "example.com",
  email_enabled = true,
  postgres = {
    host = "localhost",
    port = "5432",
    database = "my_app_prod"
  },
  _name = "production"
}
```

You can call the `config` function as many times as you like on the same
configuration names, each time the passed in table is merged into the
configuration.

> Tables with named keys are merged key by key. Arrays are not merged: an
> array replaces any existing value, so setting `{9}` on top of `{1, 2, 3}`
> results in `{9}`, and setting `{}` clears the array. An error is thrown for
> a table with both array items and named keys, or an array with missing
> (`nil`) values.

## Function Syntax

Instead of a table, a function can be passed to `config`. Inside the function,
calling a name as a function sets that value in the configuration. Passing a
function as the value creates a nested table. This is the same syntax used by
[MoonScript configurations](moon_creating_configurations.html), and lets you
add logic around your assignments:

```lua
-- config.lua
local config = require("lapis.config")

config("development", function()
  port(8080)

  if os.getenv("USE_SQLITE") then
    sqlite(function()
      database("my_app.sqlite")
    end)
  else
    postgres(function()
      database("my_app")
    end)
  end
end)
```

Names that are already global variables in Lua, like `type` or `table`, can't
be set this way because the global is found instead. Use `set` to assign them:
`set("type", "fast")`. `unset` removes previously set values, eg.
`unset("email_enabled")`.
