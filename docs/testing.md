## Testing

Lapis comes with utilities for mocking requests so you can test your
application using unit tests that run outside of Nginx.

You are free to use any testing framework you like, but in these examples we'll
be using [Busted](http://olivinelabs.com/busted/).

### Mocking A Request

Before you can test an application it must be available in a module that can be
`require`d. This means you should separate the call to `lapis.serve` and the
definition of your application class. It's recommended to put a single
application in it's own file and then have your Nginx Lua/MoonScript entry code
require that model.

In these examples we'll just define the application in the same file for
simplicity.

The method we are interested in for mocking a request is called `mock_request`
defined in `lapis.spec.request`:

```moon
import mock_request from require "lapis.spec.request"

status, body, headers = mock_request(app, url, options)
```

For example, to test a basic application with Busted we could do:

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
h
* `method` -- The HTTP method to use (defaults to `"GET"`)
* `headers` -- Additional HTTP request headers
* `host` -- The host the mocked server (defaults to `"localhost"`)
* `port` -- The port of the mocked server (defaults to `80`)
* `scheme` -- The scheme of the mocked server (defaults to `"http"`)
* `prev` -- A table of the response headers from a previous `mock_request`


If you want to simulate a series of requests that use persistant data like
cookies or sessions you can use the `prev` option in the table. It takes the
headers returned from a previous request.

```moon
r1_status, r1_res, r1_headers = mock_request MyApp!, "/first_url"
r1_status, r1_res = mock_request SessionApp!, "/second_url", prev: r1_headers
```

### Using The Test Server

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

```moon
import load_test_server, close_test_server from require "lapis.spec.server"

describe "my_site", ->
  setup ->
    load_test_server!

  teardown ->
    close_test_server!

  -- write some test that use the server here
```

The test server will either spawn a new Nginx if one isn't running, or it will
take over your development server until `close_test_server` is called. Taking
over the development server useful for seeing the raw Nginx output in the
console.

While the test server is running we are free to make queries and use
models. Database queries are transparently sent over HTTP to the test server
and executed inside of Nginx.

For example, we could write a basic unit test for a model:

```moon
  it "should create a User", ->
    import Users from require "models"
    assert Users\create name: "leafo"
```

#### `request(path, options={})`

To make HTTP request to the test server you can use the helper function
`request` found in `"lapis.spec.server"`. For example we might write a test to
make sure `/` loads without errors:

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

The function has three return values: the status code as a number, the body of
the response and any response headers in a table.

