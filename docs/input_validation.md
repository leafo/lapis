{
  title: "Input Validation"
}
# Input Validation

Any parameters that are sent to your app should be treated as untrusted input.
It is your responsibility to verify that the inputs match some expected format
before you use them directly in your models and application logic.

Some common types of inputs that web application developers often forget to verify:

* Very long inputs, eg. passing in a megabyte of text when you only expect a few characters
* Invalid unicode sequences, unprintable characters like null bytes
* Excess invisible or whitespace characters
* Nested objects when a string is expcted, or vice versa
* Numbers are substantially larger than expected, or negative (eg. fetching a page number 893289328)
* Inputs that are outside the domain of a smaller set of pre-existing options (eg. a value for an enum)
* Incorrectly treating an empty string as a provided value

The goal of the Lapis validation framework is to ensure that you can guarantee
inputs are correct before you start using them. The validation framework can
also help with cleaning up malformed text, like removing unnecessary
whitespace, or clearing out empty strings

**Note:** Lapis is currently introducing a new validation system based around
[tableshape](https://github.com/leafo/tableshape). The legacy validation system will remain unchanged until
further notice.

## Tableshape validation

[Tableshape](https://github.com/leafo/tableshape) is a Lua library that is used
for validating a value or the structure of an object, with the ability to
transform values if necessary. Tableshape type validators are plain Lua objects
that can be nested to test the structure of more complex types.

Lapis provides a handful of Tableshape compatible types and type constructors
for the validation of parameters.

Tableshape is not installed by default as a dependency of Lapis. In order to
use the tableshape powered validation function you must install tableshape:

```bash
$ luarocks install tableshape
```

Types and type-constructors are located in the `lapis.validate.types` module.

$dual_code{
moon = [[types = require "lapis.validate.types"]]
}

The `lapis.validate.types` module has its `__index` metamethod set to the
`types` object of the `tableshape` module. This enables access to any
tableshape type directly from the Lapis module without having to import both.
Any types used in the examples that are not directly documents are types
provided by tableshape (eg. `types.string` is a type provided by tableshape
that verifies a value is a string).

## Type Constructors

### `types.validate_params(param_spec, opts={})`

Creates a type checker that is suitable for extracting validated values from a
parameters objects (or any other plain Lua table). `validate_params` is similar
to `types.shape` from tableshape with a few key differences:

* Any excess fields that are not explicitly specified by the `param_spec` do not generate an error, and are left out of the transformed result
* The error returned by the type checker is not a single string value, but instead an array of errors that is compatible with the $self_ref{"errors"} pattern seen in Lapis actions.
* Because fields are specified in an array, the values are checked in the order they provided.
* The formatting of error messages can be customized

`types.validate_params` is designed to be used with the transform API of
tableshape. The resulting transformed object is a validated table of
parameters.

`param_spec` is an array of parameter specification objects object, the
parameters are checked in order:

$dual_code{
moon = [[
test_params = types.validate_params {
  {"user_id", types.db_id}
  {"bio", types.empty + types.limited_text 256 }
  {"privacy", types.one_of {"yes", "no"} }
}

params, err = test_params\transform {...}
if params
  print params.bio
  -- params is an object that contains only fields that we have validated
]],
lua = [[
local test_params = types.validate_params({
  {"user_id", types.db_id}
  {"bio", types.empty + types.limited_text(256) }
  {"privacy", types.one_of({"yes", "no"}) }
})

local params, err = test_params\transform {...}
if params then
  -- params is an object that contains only fields that we have validated
end

}

### `types.assert_error(t)`

Wraps tableshape type checker to yield an error when checking/transforming
fails. The yielded error is compatible with Lapis error handling (eg.
`assert_error` & `capture_errors`).

This can be used to simplify code paths, as it is no longer necessarry to check
for the error case when validating an input since the error will be passed up
the stack to the enclosing `capture_errors`.

## Builtin types

### `types.empty`

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

**Note:** Transforming returns `nil`, and an error on failure. Transforming an
invalid value and only checking the first return value may not be desirable.
The transform method can be combined with a type check to ensure an empty value
is provided. When using nested type checkers, like `types.shape` and
`table.validate_params`, tableshape is aware of this distinction and no
additional code is necessary.

$dual_code{
moon = [[
some_value = ...
if types.empty some_value
  print "some value is empty!"
  result = types.empty\transform some_value
]]
}


### `types.valid_text`

Matches a string that is valid UTF8. Invalid characters sequences or
unprintable charactres will cause validation to valid.

### `types.cleaned_text`

Matches a string, transforms it such that any invalid UTF8 sequences and
non-printable charactres are stripped (eg removing `null` bytes)

### `types.trimmed_text`

Matches a string that is valid UTF8, and transforms such that any whitespace or
empty UTF8 characters stripped from either side.

### `types.truncated_text(len)`

Matches a string that is valid UTF8, and transforms it such that it is `len`
characters or shorter. Note that length is UTF8 aware, and will count truncate
by the number of characters and not bytes.

### `types.limited_text(max_len, min_len=1)`

Matches a string that is valid UTF8

### `types.db_id`

### `types.db_enum(enum)`


## Assert Valid

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

    create_the_user @params
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

  create_the_user(self.params)
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
* `min_length: Min_Length` -- value must be at least `Min_Length` chars
* `max_length: Max_Length` -- value must be at most `Max_Length` chars
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

## Creating a Custom Validator

Custom validators can be defined like so:

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
