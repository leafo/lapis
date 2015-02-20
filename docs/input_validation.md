title: Input Validation
--
# Input Validation

## Example Validation

Lapis comes with a set of validators for working with external inputs. Here's a
quick example:

```lua
local lapis = require("lapis")
local app_helpers = require("lapis.application")
local validate = require("lapis.validate")

local capture_errors = app_helpers.capture_errors

local app = lapis.Aplication()

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

```

```moon
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
```

`assert_valid` takes two arguments, a table to be validated, and a second array
table with a list of validations to perform. Each validation is the following format:

    { Validation_Key, [Error_Message], Validation_Function: Validation_Argument, ... }

`Validation_Key` is the key to fetch from the table being validated.

Any number of validation functions can be provided. If a validation function
takes multiple arguments, an array table can be passed

`Error_Message` is an optional second positional value. If provided it will be
used as the validation failure error message instead of the default generated
one. Because of how Lua tables work, it can also be provided after the
validation functions as demonstrated in the example above.

## Validation Functions

* `exists: true` -- check if the value exists and is not an empty string
* `file_exists: true` -- check if the value is a file upload
* `min_length: Min_Length` -- value must be at least `Min_Length` chars
* `max_length: Max_Length` -- value must be at most `Max_Length` chars
* `is_integer: true` -- value matches integer pattern
* `is_color: true` -- value matches CSS hex color (eg. `#1234AA`)
* `is_file: true` -- value is an uploaded file, see [File Uploads][0]
* `equals: String` -- value is equal to String
* `type: String` -- type of value is equal to String
* `one_of: {A, B, C, ...}` -- value is equal to one of the elements in the array table


## Creating a Custom Validator

Custom validators can be defined like so:

```lua
local validate = require("lapis.validate")

validate.validate_functions.integer_greater_than = function(input, min)
  local num = tonumber(input)
  return num and num > min, "%s must be greater than " .. min
end

local app_helpers = require("lapis.application")
local capture_errors = app_helpers.capture_errors

local app = lapis.Aplication()

app:match("/", capture_errors(function(self)
  validate.assert_valid(self.params, {
    { "number", integer_greater_than = 100 }
  })
end))
```

```moon
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
```

## Manual Validation

In addition to `assert_valid` there is one more useful validation function:

```lua
local validate = require("lapis.validate").validate
```

```moon
import validate from require "lapis.validate"
```

* `validate(object, validation)` -- takes the same exact arguments as
  `assert_valid`, but returns either errors or `nil` on failure instead of
  yielding the error.

