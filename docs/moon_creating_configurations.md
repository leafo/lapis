{
  title: "MoonScript Configuration Syntax"
}
<div class="override_lang"></div>

# MoonScript Configuration Syntax

## Configuration Example

The MoonScript configuration builder syntax uses function calls to define
variables. The advantage to this approach over using a Lua table literal is
that you can have logic surrounding your assignments. You can also freely mix
regular table objects.

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
    mood "happy"

  extra ->
    name "beef"
    shoe_size 12

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

