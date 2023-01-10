{
  title: "Input Validation"
}
# Input Validation

Any parameters that are sent to your application should be treated as untrusted
input. It is your responsibility to verify that the inputs match some expected
format before you use them directly in your models and application logic.

Some common types of inputs that web application developers often forget to
verify:

* Very long inputs, eg. receiving a megabyte of text when you only expect a few characters
* Invalid Unicode sequences, unprintable characters, or control codes
* Excess invisible characters or whitespace
* Type mismatch, like expecting a string when an object is provided
* Numbers that are substantially larger than expected, or negative (eg. fetching a page number 893289328)
* Inputs that are outside the domain of a smaller set of pre-existing options (eg. a value for an enum)
* Incorrectly treating an empty string as a provided value

The Lapis validation module helps you ensure that inputs are correct and safe
before you start using them. Validation is also able to *transform* malformed
input to turn it into something usable, eg. stripping whitespace from the start
and end of a string.

> Lapis is currently introducing a new validation system based around
> [Tableshape](https://github.com/leafo/tableshape). The legacy validation
> functions will remain unchanged until further notice, but we recommend using
> the Tableshape validation when possible.

## Tableshape Validation

[Tableshape](https://github.com/leafo/tableshape) is a Lua library that is used
for validating a value or the structure of an object. It includes the ability
to *transform* values, which can be used to repair inputs that don't quite
match the expected criteria. Tableshape type validators are plain Lua objects
that can be composed or nested to verify the structure of more complex types.

Lapis provides a handful of Tableshape compatible types and type constructors
for the validation of request parameters.

Tableshape is not installed by default as a dependency of Lapis. In order to
use the Tableshape powered validation types you must install Tableshape:

```bash
$ luarocks install tableshape
```

Types and type-constructors are located in the `lapis.validate.types` module.

$dual_code{
moon = [[types = require "lapis.validate.types"]]
}

> The `lapis.validate.types` module has its `__index` metamethod set to the
> `types` object of the `tableshape` module. This enables access to any
> Tableshape type directly from the Lapis module without having to import both.
> Any types used in the examples below that are not directly documented are
> types provided by Tableshape (eg. `types.string` is a type provided by
> Tableshape that verifies a value such that `type(value) == "string"`).


### `with_params(t, fn)`

The `with_params` is a helper function for wrapping an action function such
that it only runs if fields from $self_ref{"params"} can be validated. The
validated parameter table is passed as the first argument to `fn`.

> $self_ref{"params"} is left unchanged. This enables the calling of nested
> functions that use `with_params` to work with other sets of parameters

It returns a new function that is designed to be called with a *request object*
as the first argument.

The argument, `t`, can either be a Tableshape type, or it can be a plain Lua
table that will be converted into a type using `types.params_shape(t)`.


$dual_code{
moon = [[
lapis = require "lapis"
import capture_errors_json from require "lapis.application"

types = require "lapis.validate.types"
import with_params from require "lapis.validate"

class App extends lapis.Application
  "/user/:id": capture_errors_json with_params {
    {"id", types.db_id}
    {"action", types.one_of {"delete", "update"}}
  }, (params) =>
    print "Perform", params.action, "on user", params.id
]],
lua = [[
local lapis = require "lapis"
local capture_errors_json = require("lapis.application").capture_errors_json
local with_params = require("lapis.validate").with_params

local app = lapis.Application()

app:post("/user/:id", capture_errors_json(with_params({
  {"id", types.db_id},
  {"action", types.one_of {"delete", "update"}}
}, function(self, params)
  print("Perform", params.action, "on user", params.id)
end)))

return app
]]
}

The params type, `t`, is wrapped in `types.assert_error`. If validation fails
then an error is raised for the nearest `capture_errors`. In the example above,
`capture_errors_json` is used to display errors as a JSON response.

### Type Constructors

#### `types.params_shape(param_spec, [opts])`

Creates a type checker that is suitable for extracting validated values from a
parameters objects (or any other plain Lua table). `params_shape` is similar
to `types.shape` from Tableshape with a few key differences:

* Fields to verify are specified in an array of tuples, values are checked in the order they provided.
* Any excess fields that are not explicitly specified within `param_spec` do not generate an error, and are left out of the transformed result.
* The error returned by the type checker is not a single string value, but instead an array of errors that is compatible with the $self_ref{"errors"} pattern seen in Lapis actions.
* The formatting of error messages can be customized.
* A new object is always returned from transform, even if the input matches the output

`types.params_shape` is designed to be used with the transform API of
Tableshape. The resulting transformed object is a validated table of
parameters.

`param_spec` is an array of parameter specification objects object, the
parameters are checked in order:

$dual_code{
moon = [[
types = require "lapis.validate.types"

test_params = types.params_shape {
  {"user_id", types.db_id}
  {"bio", types.empty + types.limited_text 256 }
  {"confirm", types.literal("yes"), error: "Please check confirm" }
}

params, err = test_params\transform {...}
if params
  print params.bio
  -- params is an object that contains only fields that we have validated
]],
lua = [[
local types = require("lapis.validate.types")

local test_params = types.params_shape({
  {"user_id", types.db_id},
  {"bio", types.empty + types.limited_text(256) },
  {"confirm", types.literal("yes"), error = "Please check confirm" }
})

local params, err = test_params:transform({...})
if params then
  -- params is an object that contains only fields that we have validated
end
]]
}

The following options are supported via the second argument:

$options_table{
  {
    name = "error_prefix",
    description = "Prefix all error messages with this substring"
  }
}

Each item in `params_spec` is a Lua table that matches the following format:

    {"field_name", type_checker, additional_options...}

`field_name` must be a string, `type_checker` must be an instance of a
Tableshape type checker.

Additional options are provided as hash table properties of the table. The
following options are supported:

$options_table{
  {
    name = "error",
    description = "A string to replace the error message with if the field fails validation"
  },
  {
    name = "label",
    description = "A prefix to be used in place of the field name when generating an error message"
  },
  {
    name = "as",
    description = "The name to store the resulting value as in the output transformed object. By default, the field name is used"
  }
}

#### `types.assert_error(t)`

Wraps a Tableshape type checker to yield an error when checking/transforming
fails. The yielded error is compatible with Lapis error handling (eg.
`assert_error` & `capture_errors`).

This can be used to simplify code paths, as it is no longer necessary to check
for the error case when validating an input since the error will be passed up
the stack to the enclosing `capture_errors`.

$dual_code{
moon = [[
types = require "lapis.validate.types"
assert_empty = types.assert_error(types.empty)

some_value = ...

empy_val = assert_empty\transform some_value

print "We are guaranteed to have an empty value"
]]}


### Builtin types

#### `types.empty`

Matches either `nil`, an empty string, or a string of whitespace. Empty and
whitespace strings are transformed to `nil`.

$dual_code{
lua = [[
types.empty("") --> true
types.empty("  ") --> true
types.empty("Hello") --> false

types.empty:transform("") --> nil
types.empty:transform("   ") --> nil
types.empty:transform(nil) --> nil
]],
moon = [[
types.empty "" --> true
types.empty "  " --> true
types.empty "Hello" --> false

types.empty\transform "" --> nil
types.empty\transform "   " --> nil
types.empty\transform nil --> nil
]]
}

> On failure, `transform` returns `nil`, and an error. Transforming an invalid
> value with `types.empty` and only checking the first return value may not be
> desirable.  The transform method can be combined with a type check to ensure
> an empty value is provided. When using nested type checkers, like
> `types.shape` and `table.params_shape`, Tableshape is aware of this
> distinction and no additional code is necessary.
>
> $dual_code{
moon = [[
some_value = ...
if types.empty some_value
  print "some value is empty!"
  result = types.empty\transform some_value
]]
}
> Alternatively, `types.assert` or `types.assert_error` can be used to
> guarantee the value matches the type checker

#### `types.valid_text`

Matches a string that is valid UTF8. Invalid characters sequences or
unprintable characters will cause validation to valid.

$dual_code{
moon = [[
types.valid_text "hello" --> true
types.valid_text "hel\0o" --> nil, "expected valid text"
]],
lua = [[
types.valid_text("hello") --> true
types.valid_text("hel\0o") --> nil, "expected valid text"
]]
}


#### `types.cleaned_text`

Matches a string, transforms it such that any invalid UTF8 sequences and
non-printable characters are stripped (eg removing `null` bytes)

$dual_code{
moon = [[
types.cleaned_text\transform "hello"  --> "hello"
types.cleaned_text\transform "hel\0o" --> "helo"
types.cleaned_text\transform 55 --> nil, "expected text"
]],
lua = [[
types.cleaned_text:transform("hello")  --> "hello"
types.cleaned_text:transform("hel\0o") --> "helo"
types.cleaned_text:transform(55) --> nil, "expected text"
]]
}


#### `types.trimmed_text`

Matches a string that is valid UTF8, and transforms such that any whitespace or
empty UTF8 characters stripped from either side.

$dual_code{
moon = [[
types.trimmed_text\transform "hello" --> "hello"
types.trimmed_text\transform " wor ld \t " --> "wor ld"
]],
lua = [[
types.trimmed_text:transform("hello") --> "hello"
types.trimmed_text:transform(" wor ld \t ") --> "wor ld"
]]
}

#### `types.truncated_text(len)`

Matches a string that is valid UTF8, and transforms it such that it is `len`
characters or shorter. Note that length is UTF8 aware, and will truncate by the
number of characters and not bytes.

$dual_code{
moon = [[
types.truncated_text(5)\transform "hello" --> "hello"
types.truncated_text(5)\transform "hi world" --> "hi wo"

-- invalid types are rejected
types.truncated_text(5)\transform(true) --> nil, "expected text"
]],
lua = [[
types.truncated_text(5):transform("hello") --> "hello"
types.truncated_text(5):transform("hi world") --> "hi wo"

-- invalid types are rejected
types.truncated_text(5):transform(true) --> nil, "expected text"
]]
}


#### `types.limited_text(max_len, min_len=1)`

Matches a string that is valid UTF8 and has a length within the specified range
of `min_len` to `max_len`, inclusive. Note that length is UTF8 aware, and will
count by the number of characters and not bytes.

$dual_code{
moon = [[
limit5 = types.limited_text 5

limit5 "hello"
limit5 "hi world" --> nil, "expected text between 1 and 5 characters"

-- invalid types are rejected
limit5 12 --> nil, "expected text between 1 and 5 characters"
]],
lua = [[
local limit5 = types.limited_text(5)

limit5("hello")
limit5("hi world") --> nil, "expected text between 1 and 5 characters"

-- invalid types are rejected
limit5(12) --> nil, "expected text between 1 and 5 characters"
]]
}

#### `types.db_id`

Matches number or string that represents an integer that is suitable for the
default 4 byte `serial` type of a PostgreSQL database column. The value is
transformed to a number.

$dual_code{
moon = [[
types.db_id\transform "0" -->  0
types.db_id\transform "2392" --> 2392

types.db_id\transform -5 --> nil, "expected database ID integer"
types.db_id\transform "-5" --> nil, "expected database ID integer"
types.db_id\transform "42.8" --> nil, "expected database ID integer"

-- value is too big
types.db_id\transform "29328302830230" --> nil, "expected database ID integer"
]],
lua = [[
types.db_id:transform("0") -->  0
types.db_id:transform("2392") --> 2392

types.db_id:transform(-5) --> nil, "expected database ID integer"
types.db_id:transform("-5") --> nil, "expected database ID integer"
types.db_id:transform("42.8") --> nil, "expected database ID integer"

-- value is too big
types.db_id:transform("29328302830230") --> nil, "expected database ID integer"
]]
}


#### `types.db_enum(enum)`

Matches from the set of values contained by a `db.enum` object. Transforms the
value to the integer value of the enum using `for_db`.

$dual_code{
moon = [[
import enum from require "lapis.db.model"

statuses = enum {
  default: 1
  banned: 2
  deleted: 3
}

check_status = types.db_enum statuses

check_status\transform "default" --> 1
check_status\transform "invalid" --> nil, "expected enum(default, banned, deleted)"

check_status\transform 2 --> 2
check_status\transform "2" --> 2

-- value out of range is rejected
check_status\transform 5 --> nil, "expected enum(default, banned, deleted)"
]],
lua = [[
local model = require "lapis.db.model"

local statuses = model.enum {
  default = 1,
  banned = 2,
  deleted = 3
}

local check_status = types.db_enum(statuses)

check_status:transform("default") --> 1
check_status:transform("invalid") --> nil, "expected enum(default, banned, deleted)"

check_status:transform(2) --> 2
check_status:transform("2") --> 2

-- value out of range is rejected
check_status:transform(5) --> nil, "expected enum(default, banned, deleted)"

]]
}


## Assert Valid

> **This is the legacy validation system.** Due to shortcomings addressed by
> the Tableshape validation system, it is not recommended to `assert_valid` and
> related functions any more

The `assert_valid` function is Lapis's legacy validation framework. It provides
a simple set of validation functions. Here's a complete example:

$dual_code{
moon = [[
import capture_errors from require "lapis.application"
import assert_valid from require "lapis.validate"

class App extends lapis.Application
  "/create-user": capture_errors =>

    assert_valid @params, {
      { "username", exists: true, min_length: 2, max_length: 25 }
      { "password", exists: true, min_length: 2 }
      { "password_repeat", equals: @params.password }
      { "email", exists: true, min_length: 3 }
      { "accept_terms", equals: "yes", "You must accept the Terms of Service" }
    }

    create_the_user {
      username: @params.username
      password: @params.password
      email: @params.email
    }
    render: true
]],
lua = [[
local lapis = require("lapis")
local app_helpers = require("lapis.application")
local validate = require("lapis.validate")

local capture_errors = app_helpers.capture_errors

local app = lapis.Application()

app:match("/create-user", capture_errors(function(self)
  validate.assert_valid(self.params, {
    { "username", exists = true, min_length = 2, max_length = 25 },
    { "password", exists = true, min_length = 2 },
    { "password_repeat", equals = self.params.password },
    { "email", exists = true, min_length = 3 },
    { "accept_terms", equals = "yes", "You must accept the Terms of Service" }
  })

  create_the_user({
    username = self.params.username,
    password = self.params.password,
    email = self.params.email
  })
  return { render = true }
end))

return app
]]}


`assert_valid` takes two arguments, a table to be validated, and a second array
table with a list of validations to perform. Each validation is the following format:

    { Validation_Key, [Error_Message], Validation_Function: Validation_Argument, ... }

`Validation_Key` is the key to fetch from the table being validated.

Any number of validation functions can be provided. If a validation function
takes multiple arguments, pass an array table. (Note: A single table argument
cannot be used, it will be unpacked into arguments.)

`Error_Message` is an optional second positional value. If provided it will be
used as the validation failure error message instead of the default generated
one. Because of how Lua tables work, it can also be provided after the
validation functions as demonstrated in the example above.

### Validation Functions

* `exists: true` -- check if the value exists and is not an empty string
* `matches_pattern: pat` -- value is a string that matches the Lua pattern provided by `pat`
* `min_length: Min_Length` -- value must be at least `Min_Length` chars (Warning: this counts by number of bytes, not characters)
* `max_length: Max_Length` -- value must be at most `Max_Length` chars (Warning: this counts by number of bytes, not characters)
* `is_integer: true` -- value matches integer pattern
* `is_color: true` -- value matches CSS hex color (eg. `#1234AA`)
* `is_file: true` -- value is an uploaded file, see [File Uploads][0]
* `equals: String` -- value is equal to String
* `type: String` -- type of value is equal to String
* `one_of: {A, B, C, ...}` -- value is equal to one of the elements in the array table

### Optional validations

You can set `optional` to true for a validation to make it validate only when
some value is provided. If the parameter's value is `nil`, then the validation
will skip it without failure.

$dual_code{
moon = [[
assert_valid @params, {
  { "color", exists: true, min_length: 2, max_length: 25, optional: true },
}
]],
lua = [[
validate.assert_valid(self.params, {
  { "color", exists = true, min_length = 2, max_length = 25, optional = true },
})
]]}

### Creating a Custom Validator

Custom validators for use in `assert_valid` can be defined like so:

$dual_code{
moon = [[
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
]],
lua = [[
local validate = require("lapis.validate")

validate.validate_functions.integer_greater_than = function(input, min)
  local num = tonumber(input)
  return num and num > min, "%s must be greater than " .. min
end

local app_helpers = require("lapis.application")
local capture_errors = app_helpers.capture_errors

local app = lapis.Application()

app:match("/", capture_errors(function(self)
  validate.assert_valid(self.params, {
    { "number", integer_greater_than = 100 }
  })
end))
]]}

### Manual Validation

In addition to `assert_valid` there is one more useful validation function:

$dual_code{
moon = [[
import validate from require "lapis.validate"
]],
lua = [[
local validate = require("lapis.validate").validate
]]}

* `validate(object, validation)` -- takes the same exact arguments as
  `assert_valid`, but returns either errors or `nil` on failure instead of
  yielding the error.

[0]: utilities.html#file-uploads
