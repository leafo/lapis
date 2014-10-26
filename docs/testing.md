title: Testing
--
# Testing

Lapis comes with utilities for handling two types of testing.

The first type is request mocking. Mocking a request simulates a HTTP request
to your application, bypassing any real HTTP requests and Nginx. The advantage
of this method is that it's faster and errors happen within the test process.

The second type uses the test server. The test server is a temporary Nginx
server spawned for the duration of your tests that allows you to issue full
HTTP requests. The advantage is you can test both Nginx configuration and your
application at the same time. It very closely resembles how your application
will run in production.

You are free to use any testing framework you like, but in these examples we'll
be using [Busted](http://olivinelabs.com/busted/).

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

For example, to test a basic application with
[Busted](http://olivinelabs.com/busted/) we could do:

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
* `host` -- The host the mocked server (defaults to `"localhost"`)
* `port` -- The port of the mocked server (defaults to `80`)
* `scheme` -- The scheme of the mocked server (defaults to `"http"`)
* `prev` -- A table of the response headers from a previous `mock_request`


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

## Using the Test Server

While mocking a request is useful, it doesn't give you access to the entire
stack that your application uses. For that reason you can spawn up a *test*
server which you can issue real HTTP requests to.

The test server runs inside of the `test` environment (compared to
`development` and `production`). This enables you to have a separate database
connection for tests so you are free to delete and create rows in the database
without messing up your development state.


The two functions that control the test server are `load_test_server` and
`close_test_server`, and they can be found in `"lapis.spec.server"`.

If you are using Busted then you might use these functions as follows:

```lua
local spec_server = require("lapis.spec.server")

describe("my site", function()
  setup(function()
    spec_server.load_test_server()
  end)

  teardown(function()
    spec_server.close_test_server()
  end)

  -- write some tests that use the server here
end)
```


```moon
import load_test_server, close_test_server from require "lapis.spec.server"

describe "my_site", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  -- write some tests that use the server here
```

The test server will either spawn a new Nginx if one isn't running, or it will
take over your development server until `close_test_server` is called. Taking
over the development server is useful for seeing the raw Nginx output in the
console.

While the test server is running we are free to make queries and use
models. Database queries are transparently sent over HTTP to the test server
and executed inside of Nginx.

For example, we could write a basic unit test for a model:

```lua
  it("should create a User", function()
    local Users = require("models").Users
    assert(Users:create({ name = "leafo" })
  end)
```


```moon
  it "should create a User", ->
    import Users from require "models"
    assert Users\create name: "leafo"
```

### `request(path, options={})`

To make HTTP request to the test server you can use the helper function
`request` found in `"lapis.spec.server"`. For example we might write a test to
make sure `/` loads without errors:

```lua
local spec_server = require("lapis.spec.server")
local request = spec_server.request

describe("my site", function()
  setup(function()
    spec_server.load_test_server()
  end)

  teardown(function()
    spec_server.close_test_server()
  end)

  it("should load /", function()
    local status, body, headers = request("/")
    assert.same(200, status)
  end)
end)
```

```moon
import load_test_server, close_test_server, request
  from require "lapis.spec.server"

describe "my_site", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  it "should load /", ->
    status, body, headers = request "/"
    assert.same 200, status

```

`path` is either a path of a full URL to request against the test server. If it
is a full URL then the hostname of the URL is extracted and inserted as the
host header.

The `options` argument can be used to further configure the request. It
supports the following options in the table:

* `post` -- A table of POST parameters. Sets default method to `"POST"`,
  encodes the table as the body of the request and sets the `Content-type`
  header to `application/x-www-form-urlencoded`
* `method` -- The HTTP method to use (defaults to `"GET"`)
* `headers` -- Additional HTTP request headers
* `expect` -- What type of response to expect, currently only supports
  `"json"`. It will parse the body automatically into a Lua table or throw an
  error if the body is not valid JSON.
* `port` -- The port of the server, defaults to the randomly assigned port defined autmatically when running tests

The function has three return values: the status code as a number, the body of
the response and any response headers in a table.

