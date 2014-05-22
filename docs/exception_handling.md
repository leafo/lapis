## Exception Handling

Lapis comes with a set of exception handling routines for recovering from errors
and displaying something appropriate. We use the `capture_errors` helper to
capture any errors and run an error handler.

When we refer to exceptions we are talking about messages thrown explicitly by
the programmer. This doesn't include runtime errors. You should use `pcall` if
you want to capture runtime errors as you would normally do in Lua.

Lua doesn't have the concept of exceptions like most other languages. Instead
Lapis creates an exception handling system using coroutines. We must define the
scope in which we will capture errors. We do that using the `capture_errors`
helper. Then we can throw a raw error using `yield_error`.

```moon
import capture_errors, yield_error from require "lapis.application"

class App extends lapis.Application
  "/do_something": capture_errors =>
    yield_error "something bad happened"
    "Hello!"
```

What happens when there is an error? The action will stop executing at the
first error, and then the error handler is run. The default one will set an
array like table of errors to `@errors` and return `render: true`. In your view
you can then display the errors.

If you want to have a custom error handler you can invoke `capture_errors` with
a table: (note that `@errors` is set before the custom handler)

```moon
class App extends lapis.Application
  "/do_something": capture_errors {
    on_error: =>
      log_errors @errors -- you would supply the log_errors method
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
error, otherwise the first argument is returned.

`assert_error` is very handy with database methods, which make use of this
idiom.

```moon
import capture_errors, assert_error from require "lapis.application"

class App extends lapis.Application
  "/": capture_errors =>
    user = assert_error Users\find id: "leafo"
    "result: #{user.id}"
```


