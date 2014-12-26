title: Exception Handling 
--
# Exception Handling

## The Kinds of Errors

Lapis makes a distinction between two kinds of errors: Recoverable and
non-recoverable errors. Errors thrown by Lua's runtime during executuion or
calls to  `error` are considered non-recoverable. (This also includes the Lua
built-in function `assert`)

Because non-recoverable errors aren't expected to be captured by the user,
Lapis catches them and prints an exception message to the browser. Any action
that may have been running is aborted and Lapis prints a special view showing
the stack trace along with setting the status to `500`.

These kinds of errors typically are an indicator of a bug or other serious
issue and should be fixed.

Recoverable errors are a user controlled way of aborting the execution of an
action to run a special error handling function. They are implemented using
coroutines instead of Lua's error system.

Examples include non-valid inputs from users, or missing records from the
database.

## Capturing Recoverable Errors

The `capture_errors` helper is used wrap an action such that it can capture
errors and run an error handler.

This does not capture runtime errors. You should use `pcall` if you
want to capture runtime errors as you would normally do in Lua.

Lua doesn't have the concept of exceptions like most other languages. Instead
Lapis creates an exception handling system using coroutines. We must define the
scope in which we will capture errors. We do that using the `capture_errors`
helper. Then we can throw a raw error using `yield_error`.


```lua
local lapis = require("lapis")
local app_helpers = require("lapis.application")

local capture_errors, yield_error = app_helpers.capture_errors, app_helpers.yield_error

local app = lapis.Application()

app:match("/do_something", capture_errors(function(self)
  yield_error("something bad happened")
  return "Hello!"
end))
```

```moon
import capture_errors, yield_error from require "lapis.application"

class App extends lapis.Application
  "/do_something": capture_errors =>
    yield_error "something bad happened"
    "Hello!"
```

What happens when there is an error? The action will stop executing at the
first error, and then the error handler is run. The default error handler will
set an array like table of errors in <span
class="for_moon">`@errors`</span><span class="for_lua">`self.errors`</span> and
return <span class="for_moon">`render: true`</span><span class="for_lua">`{
render = true }`</span>. In your view you can then display the errors. This
means that if you have a named route the view of that route will render. You
should then code your view to sometimes have a `errors` table.

If you want to have a custom error handler you can invoke `capture_errors` with
a table: (note that <span class="for_moon">`@errors`</span><span
class="for_lua">`self.errors`</span> is set before the custom handler)

```lua
app:match("/do_something", capture_errors({
  on_error = function(self)
    log_erorrs(self.errors) -- you would supply the log_errors function
    return { render = "my_error_page", status = 500 }
  end,
  function(self)
    if self.params.bad_thing then
      yield_error("something bad happened")
    end
    return { render = true }
  end
}))
```

```moon
class App extends lapis.Application
  "/do_something": capture_errors {
    on_error: =>
      log_errors @errors -- you would supply the log_errors function
      render: "my_error_page", status: 500

    =>
      if @params.bad_thing
        yield_error "something bad happened"
      render: true
  }
```

`capture_errors` when called with a table will use the first positional value
as the action.

If you're building a JSON API then another method is provided,
`capture_errors_json`, which renders the errors in a JSON object like so:

```lua
local lapis = require("lapis")
local app_helpers = require("lapis.application")

local capture_errors_json, yield_error = app_helpers.capture_errors_json, app_helpers.yield_error

local app = lapis.Application()

app:match("/", capture_errors_json(function(self)
  yield_error("something bad happened")
end))
```

```moon
import capture_errors_json, yield_error from require "lapis.application"

class App extends lapis.Application
  "/": capture_errors_json =>
    yield_error "something bad happened"
```

Would render (with the correct content type):

```json
{ errors: ["something bad happened"] }
```

### `assert_error`

It is idiomatic in Lua to return `nil` and an error message from a function
when it fails. For this reason the helper `assert_error` exists. If the first
argument is falsey (`nil` or `false`) then the second argument is thrown as an
error, otherwise all the arguments are returned from the function unchanged.

`assert_error` is very handy with database methods, which make use of this
idiom.

```lua
local lapis = require("lapis")
local app_helpers = require("lapis.application")

local capture_errors, assert_error = app_helpers.capture_errors, app_helpers.assert_error

local app = lapis.Application()

app:match("/", capture_errors(function(self)
  local user = assert_error(Users:find({id = "leafo"}))
  return "result: " .. user.id
end))

```

```moon
import capture_errors, assert_error from require "lapis.application"

class App extends lapis.Application
  "/": capture_errors =>
    user = assert_error Users\find id: "leafo"
    "result: #{user.id}"
```


