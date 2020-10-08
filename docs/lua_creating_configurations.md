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

You can call the `config` function as many time you like on the same
configuration names, each time the passed in table is merged into the
configuration.
