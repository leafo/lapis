{
  title: "Testing"
}
# Testing <span data-keywords="spec"></span>

Lapis comes with modes of executing tests:

**Request mocking:** Mocking a request simulates a HTTP request
to your application, bypassing any real HTTP requests and Nginx. The advantage
of this method is that it's faster and errors happen within the test process.

**Test Server:** A temporary Nginx server is spawned for the duration of your
tests that allows you to issue full HTTP requests. The advantage of this method
is you can perform full integration tests across both your Nginx configuration
and your application code. Your application code also has full access to the
`ngx.*` Lua API. It very closely resembles how your application will run in
production.

Both modes support using a separate database connection via the `test`
environment for writing tests for your models.

You are free to use any testing framework you like, but in these examples we'll
be using [Busted][].

> Lapis will detect when it is running in Busted and enable the test
> environment accordingly. If you are using any other test library it is your
> responsibility to ensure you have enabled the test environment or you may
> risk data loss in you development database.

## Mocking a Request

In order to test your application it should be a Lua module that can be
`require`d without any side effects. Ideally you'll have a separate file for
each application and you can get the application class just by loading the
module.

In these examples we'll define the application in the same file as the tests
for simplicity.

A request can be mocked using the `mock_request` function defined in
`lapis.spec.request`:

```lua
local mock_request = require("lapis.spec.request").mock_request

local status, body, headers = mock_request(app, url, options)
```

```moon
import mock_request from require "lapis.spec.request"

status, body, headers = mock_request(app, url, options)
```

For example, to test a basic application with [Busted][] we could do:

```lua
local lapis = require("lapis.application")
local mock_request = require("lapis.spec.request").mock_request

local app = lapis.Application()

app:match("/hello", function(self)
  return "welcome to my page"
end)

describe("my application", function()
  it("should make a request", function()
    local status, body = mock_request(app, "/hello")

    assert.same(200, status)
    assert.truthy(body:match("welcome"))
  end)
end)

```

```moon
lapis = require "lapis"

import mock_request from require "lapis.spec.request"

class App extends lapis.Application
  "/hello": => "welcome to my page"

describe "my application", ->
  it "should make a request", ->
    status, body = mock_request App, "/hello"

    assert.same 200, status
    assert.truthy body\match "welcome"
```

`mock_request` simulates an `ngx` variable from the Lua Nginx module and
executes the application. The `options` argument of `mock_request` can be used
to control the kind of request that is simulated. It takes the following
options in a table:

* `get` --  A table of GET parameters to add to the url
* `post` -- A table of POST parameters (sets default method to `"POST"`)
* `method` -- The HTTP method to use (defaults to `"GET"`)
* `headers` -- Additional HTTP request headers
* `cookies` -- A table of cookies to insert into headers
* `session` -- A session table to encode into the cookies
* `host` -- The host the mocked server (defaults to `"localhost"`)
* `port` -- The port of the mocked server (defaults to `80`)
* `scheme` -- The scheme of the mocked server (defaults to `"http"`)
* `prev` -- A table of the response headers from a previous `mock_request`
* `allow_error` -- Don't automatically convert 500 server errors into Lua errors (defaults to `false`)

If you want to simulate a series of requests that use persistant data like
cookies or sessions you can use the `prev` option in the table. It takes the
headers returned from a previous request.

```lua
local r1_status, r1_res, r1_headers = mock_request(my_app, "/first_url")
local r2_status, r2_res = mock_request(my_app, "/second_url", { prev = r1_headers })
```

```moon
r1_status, r1_res, r1_headers = mock_request MyApp!, "/first_url"
r2_status, r2_res = mock_request MyApp!, "/second_url", prev: r1_headers
```

### Using the `test` Environment

When using a supported testing tool, like [Busted][], Lapis will automatically
detect that it is running within a test runner and change the default
environment to one called *`test`*.

The `test` environment will allow you to write a distinct configuration to be
used when tests are running. It is highly recommended to set up a distinct
database for your test suite to ensure that none of your working data is reset
when running tests, as a copy pattern is to truncate all data from a table
before running any tests that use that table.

You can add a configuration environment with separate database rules by editing
your <span class="for_moon">`config.moon`</span><span
class="for_lua">`config.lua`</span>:

> Read more about configurations on the [Configuration and
> Environments guide]($root/reference/configuration.html), and more about
> setting up a database on the [Database guide]($root/reference/configuration.html).

```lua
local config = require("lapis.config")

-- other configuration ...

config("test", {
  postgres = {
    backend = "pgmoon",
    database = "myapp_test"
  }
})

```

```moon
-- config.moon
config = require "lapis.config"

-- other configuration ...

config "test", ->
  postgres {
    backend: "pgmoon"
    database: "myapp_test"
  }
```

> Don't forget to initialize your test database by creating it and its schema
> before running the tests.

## Using the Test Server

While mocking a request is useful, it doesn't give you access to the entire
stack that your application uses. For that reason you can spawn up a *test*
server which you can issue real HTTP requests to.

It's important to realize that when using the test server there are actually
*at least two* Lua runtimes executing your code:

1. The foreground process running the test suite
2. The `nginx` server's Lua runtime -- If you have multiple workers enabled, then there can be multiple concurrent Lua runtimes. It's recommended to set `worker_processes` to `1` in the test environment.

This is an important distinction to pay attention to because any changes you
make to in-memory data in one runtime will not be seen in the other. Changes
you make to the database would be accessible to both though, as they would both
use the same configuration to connect to the same database.

Any `stub` or similar functions provided by your test suite will be unable to
change any code running in the server.

> Both runtimes have their Lapis environment set to`test`  to ensure that they
> each load the same configuration.

> There can only be one test server running at any time, meaning you can not
> parallelize your tests if you attempt to spawn multiple processes.


The `use_test_server` function will ensure that the test server is running for
the duration of the specs within the block:

```lua
local use_test_server = require("lapis.spec").use_test_server

describe("my site", function()
  use_test_server()
  -- write some tests that use the server here
end)
```


```moon
import use_test_server from require "lapis.spec"

describe "my_site", ->
  use_test_server!

  -- write some tests that use the server here
```

The test server will either spawn a new Nginx if one isn't running, or it will
take over your development server until `close_test_server` is called 
(`use_test_server` automatically calls that for you, but you can call it manually
if you wish). Taking over the development server can be useful because the same 
stdout is used, so any output from the server is written to a terminal you might 
already have open.

### `request(path, options={})`

To make HTTP request to the test server you can use the helper function
`request` found in `"lapis.spec.server"`. For example we might write a test to
make sure `/` loads without errors:

```lua
local request = require("lapis.spec.server").request
local use_test_server = require("lapis.spec").use_test_server

describe("my site", function()
  use_test_server()

  it("should load /", function()
    local status, body, headers = request("/")
    assert.same(200, status)
  end)
end)
```

```moon
import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"

describe "my_site", ->
  use_test_server!

  it "should load /", ->
    status, body, headers = request "/"
    assert.same 200, status

```

`path` is either a path or a full URL to request against the test server. If it
is a full URL then the hostname of the URL is extracted and inserted as the
`Host` header.

The `options` argument can be used to further configure the request. It
supports the following options in the table:

* `post` -- A table of POST parameters. Sets default method to `"POST"`,
  encodes the table as the body of the request and sets the `Content-type`
  header to `application/x-www-form-urlencoded`
* `data` -- The body of the HTTP request as a string. The `Content-length` header is automatically set to the length of the string
* `method` -- The HTTP method to use (defaults to `"GET"`)
* `headers` -- Additional HTTP request headers
* `expect` -- What type of response to expect, currently only supports
  `"json"`. It will parse the body automatically into a Lua table or throw an
  error if the body is not valid JSON.
* `port` -- The port of the server, defaults to the randomly assigned port defined automatically when running tests

The function has three return values: the status code as a number, the body of
the response and any response headers in a table.


### `get_current_server()`

Returns the currently attached test server. This will provide a handle to the
server that enables you to execute code within that process.

The `exec` method will execute Lua code on the server.


```lua
local get_current_server = require("lapis.spec.server").get_current_server
local use_test_server = require("lapis.spec").use_test_server

describe("my site", function()
  use_test_server()

  it("runs code on server", function()
    local server = assert(get_current_server())
    server:exec([[
      require("myapp").some_variable = 100
    ]])
  end)
end)
```

```moon
import use_test_server from require "lapis.spec"
import get_current_server from require "lapis.spec.server"

describe "my_site", ->
  use_test_server!

  it "runs code on server", ->
    server = assert get_current_server!
    server\exec [[
      require("myapp").some_variable = 100
    ]]
```

## Test Strategies

### Working with Models

When writing tests that work with your models it's useful to have a separate
test database where data can reset and generated to unit test model
functionality. By having a functioning database connection you can perform full
integration testing across your application code and the database, ensuring
that it works as intended.

The typical strategy is:

* Before every test, truncate the tables of the models that are accessed by the code that will run in the test
* Within your test suite:
  * Use a *factory* function to create any rows that may be needed for an initial state
  * Perform your tests using the models as you would in your application


Because truncating tables is a common operation, Lapis provides a
`truncate_tables` function:

> Truncate tables will **delete** all the data in the respective
> table, with no way to get it back. Because this is a dangerous operation it
> will only run when the current environment is named `test`


```moon
import truncate_tables from require "lapis.spec.db"

describe "User profiles", ->
  import Users, Profiles from require "models"

  before_each ->
    truncate_tables Users, Profiles

  user_factory = do
    user_counter = 0
    ->
      user_counter += 1
      Users\create {
        login: "user-#{user_counter}"
      }

  it "fetches or creates the user's profile", ->
    user1 = user_factory!
    user2 = user_factory!

    user1\create_profile_if_necessary!

    assert.truthy user1\get_profile!, "user1 should have a profile"
    assert.nil user2\get_profile!, "user2 should not have a profile"
```

Because some models might have *unique indexes* on certain fields, like `login`
on the User model above, we can use the *counter* pattern to ensure that our
factory function generates a new User row without conflict.

If you have many factories that you re-use across different test files, it can
be helpful to put it into a separate module that you can `require` into your
tests as needed.


 [Busted]: http://olivinelabs.com/busted/




