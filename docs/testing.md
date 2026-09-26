{
  title: "Testing"
}
# Testing <span data-keywords="spec"></span>

Lapis comes with two modes of executing tests:

**Request simulation:** Simulating a request runs an HTTP request through
your application, bypassing any real HTTP requests and Nginx. The advantage of
this method is that it's faster and errors happen within the test process.

**Test Server:** A temporary server is spawned for the duration of your tests
that allows you to issue full HTTP requests. The advantage of this method is
you can perform full integration tests across both your server configuration
and your application code. When using Nginx, your application code also has
full access to the `ngx.*` Lua API. It very closely resembles how your
application will run in production.

Both modes support using a separate database connection via the `test`
environment for writing tests for your models.

You are free to use any testing framework you like, but in these examples we'll
be using [Busted][].

> Lapis will detect when it is running in Busted and enable the test
> environment accordingly. If you are using any other test library it is your
> responsibility to ensure you have enabled the test environment or you may
> risk data loss in your development database.

## Using the `test` Environment

When using a supported testing tool, like [Busted][], Lapis will automatically
detect that it is running within a test runner and change the default
environment to one called *`test`*.

The `test` environment will allow you to write a distinct configuration to be
used when tests are running. It is highly recommended to set up a distinct
database for your test suite to ensure that none of your working data is reset
when running tests, as a common pattern is to truncate all data from a table
before running any tests that use that table.

You can add a configuration environment with separate database rules by editing
your <span class="for_moon">`config.moon`</span><span
class="for_lua">`config.lua`</span>:

> Read more about configurations on the [Configuration and
> Environments guide]($root/reference/configuration.html), and more about
> setting up a database on the [Database guide]($root/reference/database.html).

$dual_code{
lua = [[
local config = require("lapis.config")

-- other configuration ...

config("test", {
  postgres = {
    database = "myapp_test"
  }
})
]],
moon = [[
-- config.moon
config = require "lapis.config"

-- other configuration ...

config "test", ->
  postgres ->
    database "myapp_test"
]]
}

The test database needs to be created and have its schema loaded before
running tests. If you use migrations you can run them against the test
environment:

```bash
$ createdb -U postgres myapp_test
$ lapis migrate test
```

Alternatively, for a large application it can be faster to copy the schema
from your development database, along with the list of migrations that have
already been run:

```bash
$ pg_dump -s -U postgres myapp | psql -U postgres myapp_test
$ pg_dump -a -t lapis_migrations -U postgres myapp | psql -U postgres myapp_test
```

## Simulating a Request

This section covers functions from `lapis.spec.request` for testing your
application by simulating requests without a real HTTP server.

> `simulate_request` was previously named `mock_request`. The old name is still
> available as an alias.

### `simulate_request(app, url, options)`

`simulate_request` simulates a complete HTTP request to your application and
returns the response. It's useful for testing route handlers and verifying the
output of your application.

In order to test your application it should be a Lua module that can be
`require`d without any side effects. Ideally you'll have a separate file for
each application and you can get the application class just by loading the
module. `app` can either be an application class or an instance.

In these examples we'll define the application in the same file as the tests
for simplicity.

$dual_code{
lua = [[
local simulate_request = require("lapis.spec.request").simulate_request

local status, body, headers = simulate_request(app, url, options)
]],
moon = [[
import simulate_request from require "lapis.spec.request"

status, body, headers = simulate_request(app, url, options)
]]
}

For example, to test a basic application with [Busted][] we could do:

$dual_code{
lua = [[
local lapis = require("lapis")
local simulate_request = require("lapis.spec.request").simulate_request

local app = lapis.Application()

app:match("/hello", function(self)
  return "welcome to my page"
end)

describe("my application", function()
  it("should make a request", function()
    local status, body = simulate_request(app, "/hello")

    assert.same(200, status)
    assert.truthy(body:match("welcome"))
  end)
end)
]],
moon = [[
lapis = require "lapis"

import simulate_request from require "lapis.spec.request"

class App extends lapis.Application
  "/hello": => "welcome to my page"

describe "my application", ->
  it "should make a request", ->
    status, body = simulate_request App, "/hello"

    assert.same 200, status
    assert.truthy body\match "welcome"
]]
}

`simulate_request` simulates an `ngx` variable from the Lua Nginx module and
executes the application. The `options` argument of `simulate_request` can be used
to control the kind of request that is simulated. It takes the following
options in a table:

$options_table{
  {
    name = "get",
    description = "A table of GET parameters to add to the URL"
  },
  {
    name = "post",
    description = [[A table of POST parameters (sets default method to `"POST"`)]]
  },
  {
    name = "body",
    description = [[A string to use as the raw body of the request. If the `Content-type` header is `application/x-www-form-urlencoded` then it is also parsed into the POST parameters]]
  },
  {
    name = "method",
    description = "The HTTP method to use",
    default = [[`"GET"`]]
  },
  {
    name = "headers",
    description = "Additional HTTP request headers"
  },
  {
    name = "cookies",
    description = "A table of cookies to insert into headers"
  },
  {
    name = "session",
    description = "A session table to encode into the cookies"
  },
  {
    name = "host",
    description = "The host of the mocked server",
    default = [[`"localhost"`]]
  },
  {
    name = "port",
    description = "The port of the mocked server",
    default = "`80`"
  },
  {
    name = "scheme",
    description = "The scheme of the mocked server",
    default = [[`"http"`]]
  },
  {
    name = "prev",
    description = "A table of the response headers from a previous `simulate_request`"
  },
  {
    name = "allow_error",
    description = "Don't automatically convert 500 server errors into Lua errors",
    default = "`false`"
  },
  {
    name = "expect",
    description = [[Set to `"json"` to parse the response body as JSON. An error is thrown if the body is not valid JSON]]
  }
}

If you want to simulate a series of requests that use persistent data like
cookies or sessions you can use the `prev` option in the table. It takes the
headers returned from a previous request.

$dual_code{
lua = [[
local r1_status, r1_res, r1_headers = simulate_request(my_app, "/first_url")
local r2_status, r2_res = simulate_request(my_app, "/second_url", { prev = r1_headers })
]],
moon = [[
r1_status, r1_res, r1_headers = simulate_request MyApp!, "/first_url"
r2_status, r2_res = simulate_request MyApp!, "/second_url", prev: r1_headers
]]
}

### `stub_request(app, url, options)`

`stub_request` creates and returns a [Request object]($root/reference/actions.html#request-object) without
executing the full request cycle. Unlike `simulate_request`, `app` must be an
application class, not an instance. Unlike `simulate_request` which returns
status/body/headers, `stub_request` gives you direct access to the request
object itself.

This is useful for testing code that needs a request object, such as:

* Helper functions that operate on requests
* [Flow objects]($root/reference/flows.html)
* Methods like `url_for`, `build_url`, or accessing `session`/`cookies`

> **Note on `ngx` availability:** Unlike `simulate_request`, which maintains a
> mock `ngx` global throughout the request cycle, `stub_request` does not
> provide an `ngx` global after it returns. The returned request object is
> fully functional on its own, but any code that directly accesses `ngx.*` APIs
> will fail. If you need to test code that uses `ngx` directly, use
> `simulate_request` instead.

$dual_code{
lua = [[
local stub_request = require("lapis.spec.request").stub_request

local req = stub_request(app, url, options)
]],
moon = [[
import stub_request from require "lapis.spec.request"

req = stub_request app, url, options
]]
}

The returned request object has:

* `params`, `GET`, `POST` -- Populated from the URL query string and POST body
* `session`, `cookies` -- Accessible and functional
* `url_for`, `build_url` -- Working URL generation methods
* `req.method`, `req.headers`, `req.parsed_url` -- Request metadata

`stub_request` accepts the same options as `simulate_request`, plus one additional option:

$options_table{
  {
    name = "params",
    description = "A table of parameters to inject directly into the request's params (merged with GET/POST params)"
  }
}

Here's an example of using `stub_request` to test a helper function:

$dual_code{
lua = [[
local lapis = require("lapis")
local stub_request = require("lapis.spec.request").stub_request

local App = lapis.Application:extend()

App:match("user_profile", "/user/:id", function(self) end)

describe("my helper", function()
  it("generates correct URLs", function()
    local req = stub_request(App, "/")
    assert.same("/user/123", req:url_for("user_profile", {id = 123}))
  end)

  it("has access to params", function()
    local req = stub_request(App, "/test", {
      post = {name = "hello"},
      params = {id = "5"}
    })
    assert.same("hello", req.params.name)
    assert.same("5", req.params.id)
  end)

  it("has access to session", function()
    local req = stub_request(App, "/", {
      session = {user_id = 101}
    })
    assert.same(101, req.session.user_id)
  end)
end)
]],
moon = [[
lapis = require "lapis"
import stub_request from require "lapis.spec.request"

class App extends lapis.Application
  [user_profile: "/user/:id"]: =>

describe "my helper", ->
  it "generates correct URLs", ->
    req = stub_request App, "/"
    assert.same "/user/123", req\url_for "user_profile", id: 123

  it "has access to params", ->
    req = stub_request App, "/test", {
      post: {name: "hello"}
      params: {id: "5"}
    }
    assert.same "hello", req.params.name
    assert.same "5", req.params.id

  it "has access to session", ->
    req = stub_request App, "/", {
      session: {user_id: 101}
    }
    assert.same 101, req.session.user_id
]]
}

### `simulate_action(app, [url], [opts], fn)`

`simulate_action` runs `fn` as an action within a simulated request and
returns whatever `fn` returns. `fn` is called with the request object as
`self`, so it's a convenient way to test [flows]($root/reference/flows.html),
helpers, or anything else that needs a request object. Unlike `stub_request`,
the code runs during the request cycle, so the mock `ngx` global is available.

`url` defaults to `"/"`, and `opts` takes the same options as
`simulate_request`. If you provide `opts` then you must also provide `url`.
`app` must be an application class.

> `simulate_action` was previously named `mock_action`. The old name is still
> available as an alias.

$dual_code{
lua = [[
local lapis = require("lapis")
local simulate_action = require("lapis.spec.request").simulate_action

local App = lapis.Application:extend()
App:match("user_profile", "/user/:id", function(self) end)

describe("my flow", function()
  it("runs in a request", function()
    local url, user_id = simulate_action(App, "/", {
      session = { user_id = 5 }
    }, function(self)
      return self:url_for("user_profile", { id = 10 }), self.session.user_id
    end)

    assert.same("/user/10", url)
    assert.same(5, user_id)
  end)
end)
]],
moon = [[
lapis = require "lapis"
import simulate_action from require "lapis.spec.request"

class App extends lapis.Application
  [user_profile: "/user/:id"]: =>

describe "my flow", ->
  it "runs in a request", ->
    url, user_id = simulate_action App, "/", {
      session: { user_id: 5 }
    }, =>
      @url_for("user_profile", id: 10), @session.user_id

    assert.same "/user/10", url
    assert.same 5, user_id
]]
}

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

> Both runtimes have their Lapis environment set to `test` to ensure that they
> each load the same configuration.

> There can only be one test server running at any time, meaning you can not
> parallelize your tests if you attempt to spawn multiple processes.


The `use_test_server` function will ensure that the test server is running for
the duration of the specs within the block:

$dual_code{
lua = [[
local use_test_server = require("lapis.spec").use_test_server

describe("my site", function()
  use_test_server()
  -- write some tests that use the server here
end)
]],
moon = [[
import use_test_server from require "lapis.spec"

describe "my_site", ->
  use_test_server!

  -- write some tests that use the server here
]]
}

The test server will either spawn a new Nginx if one isn't running, or it will
take over your development server until `close_test_server` is called
(`use_test_server` automatically calls that for you, but you can call it manually
if you wish). Taking over the development server can be useful because the same
stdout is used, so any output from the server is written to a terminal you might
already have open.

If your application is configured to use the cqueues server then a lua-http
server is spawned instead.

If you need to control the server yourself, `load_test_server` and
`close_test_server` from `lapis.spec.server` start and stop the test server
directly. `load_test_server` takes an optional table of configuration values
that override the `test` configuration.

### `request(path, options={})`

To make an HTTP request to the test server you can use the helper function
`request` found in `"lapis.spec.server"`. For example we might write a test to
make sure `/` loads without errors:

$dual_code{
lua = [[
local request = require("lapis.spec.server").request
local use_test_server = require("lapis.spec").use_test_server

describe("my site", function()
  use_test_server()

  it("should load /", function()
    local status, body, headers = request("/")
    assert.same(200, status)
  end)
end)
]],
moon = [[
import use_test_server from require "lapis.spec"
import request from require "lapis.spec.server"

describe "my_site", ->
  use_test_server!

  it "should load /", ->
    status, body, headers = request "/"
    assert.same 200, status
]]
}

`path` is either a path or a full URL to request against the test server. If it
is a full URL then the hostname of the URL is extracted and inserted as the
`Host` header.

The `options` argument can be used to further configure the request. It
supports the following options in the table:

* `get` -- A table of GET parameters to add to the URL
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

The `exec` method will execute Lua code on the server. `exec` is only
available when using the Nginx server.


$dual_code{
lua = [[
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
]],
moon = [[
import use_test_server from require "lapis.spec"
import get_current_server from require "lapis.spec.server"

describe "my_site", ->
  use_test_server!

  it "runs code on server", ->
    server = assert get_current_server!
    server\exec [[
      require("myapp").some_variable = 100
    ]]
]]
}

## Test Strategies

### Working with Models

When writing tests that work with your models it's useful to have a separate
test database where data can be reset and generated to unit test model
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

`truncate_tables` takes any number of model classes or table names. The rows
are removed with a `DELETE` query instead of `TRUNCATE`, since it's faster on
the small tables typical of a test suite.


$dual_code{
lua = [[
local truncate_tables = require("lapis.spec.db").truncate_tables

describe("User profiles", function()
  local Users = require("models").Users
  local Profiles = require("models").Profiles

  before_each(function()
    truncate_tables(Users, Profiles)
  end)

  local user_counter = 0
  local function user_factory()
    user_counter = user_counter + 1
    return Users:create({
      login = "user-" .. user_counter
    })
  end

  it("fetches or creates the user's profile", function()
    local user1 = user_factory()
    local user2 = user_factory()

    user1:create_profile_if_necessary()

    assert.truthy(user1:get_profile(), "user1 should have a profile")
    assert.is_nil(user2:get_profile(), "user2 should not have a profile")
  end)
end)
]],
moon = [[
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
]]
}

Because some models might have *unique indexes* on certain fields, like `login`
on the User model above, we can use the *counter* pattern to ensure that our
factory function generates a new User row without conflict.

If you have many factories that you re-use across different test files, it can
be helpful to put it into a separate module that you can `require` into your
tests as needed. A factory can also fill in default values, and create any
parent rows that are needed, so that a test only has to specify the fields it
cares about. Adding an `assert_env` check ensures a factory can never write to
a non-test database:

$dual_code{
lua = [[
-- spec/factory.lua
local assert_env = require("lapis.environment").assert_env
local models = require("models")

local counter = 0
local function next_counter()
  counter = counter + 1
  return counter
end

local function user(opts)
  assert_env("test")
  opts = opts or {}
  opts.login = opts.login or ("user-" .. next_counter())
  return models.Users:create(opts)
end

local function post(opts)
  assert_env("test")
  opts = opts or {}
  opts.user_id = opts.user_id or user().id
  opts.title = opts.title or ("Post " .. next_counter())
  return models.Posts:create(opts)
end

return { user = user, post = post }
]],
moon = [[
-- spec/factory.moon
import assert_env from require "lapis.environment"
import Users, Posts from require "models"

counter = 0
next_counter = ->
  counter += 1
  counter

user = (opts={}) ->
  assert_env "test"
  opts.login or= "user-#{next_counter!}"
  Users\create opts

post = (opts={}) ->
  assert_env "test"
  opts.user_id or= user!.id
  opts.title or= "Post #{next_counter!}"
  Posts\create opts

{ :user, :post }
]]
}

In a larger test suite it's easy to forget to truncate a table that a test
uses. One approach is a module that truncates each model as it's imported into
a `describe` block:

$dual_code{
lua = [[
-- spec/models.lua
local truncate_tables = require("lapis.spec.db").truncate_tables
local before_each = require("busted").before_each

return setmetatable({}, {
  __index = function(self, name)
    local model = assert(require("models")[name], "invalid model: " .. name)
    before_each(function()
      truncate_tables(model)
    end)
    return model
  end
})
]],
moon = [[
-- spec/models.moon
import truncate_tables from require "lapis.spec.db"
import before_each from require "busted"

setmetatable {}, __index: (name) =>
  model = assert require("models")[name], "invalid model: #{name}"
  before_each -> truncate_tables model
  model
]]
}

$dual_code{
lua = [[
describe("User profiles", function()
  local models = require("spec.models")
  -- both tables are truncated before each test in this block
  local Users, Profiles = models.Users, models.Profiles

  -- ...
end)
]],
moon = [[
describe "User profiles", ->
  -- both tables are truncated before each test in this block
  import Users, Profiles from require "spec.models"

  -- ...
]]
}

> The models must be imported directly inside of a `describe` block. If they
> are imported inside of an `it` block or a hook then the truncation will not
> be registered for that test.

### Stubbing

Busted's `stub` can replace methods on your models and other modules to
isolate the code being tested. To stub a method on every instance of a model,
stub it on the class's `__base`. Take a snapshot of the stubs before each test
so they're reverted afterwards:

$dual_code{
lua = [[
describe("users", function()
  local snapshot
  before_each(function() snapshot = assert:snapshot() end)
  after_each(function() snapshot:revert() end)

  it("stubs the display name", function()
    stub(Users.__base, "get_display_name").returns("Stubbed")
    -- ...
  end)
end)
]],
moon = [[
describe "users", ->
  local snapshot
  before_each -> snapshot = assert\snapshot!
  after_each -> snapshot\revert!

  it "stubs the display name", ->
    stub(Users.__base, "get_display_name").returns "Stubbed"
    -- ...
]]
}

> Stubs only affect the Lua runtime running the tests. Code running in the
> [test server](#using-the-test-server) will not see them. Use
> `simulate_request` or `simulate_action` to test code that depends on stubs.

### CSRF Protected Actions

To test an action that validates a [CSRF token]($root/reference/utilities.html#csrf-protection),
the request must include both the token parameter and the token cookie. A
token can be created directly with `encode_with_secret`:

$dual_code{
lua = [[
local encode_with_secret = require("lapis.util.encoding").encode_with_secret
local config = require("lapis.config").get()

local key = "test-key"
local status, body = simulate_request(App, "/form", {
  post = { csrf_token = encode_with_secret({ k = key }) },
  cookies = { [config.session_name .. "_token"] = key }
})
]],
moon = [[
import encode_with_secret from require "lapis.util.encoding"
config = require("lapis.config").get!

key = "test-key"
status, body = simulate_request App, "/form", {
  post: { csrf_token: encode_with_secret { k: key } }
  cookies: { ["#{config.session_name}_token"]: key }
}
]]
}

## Functions

The following functions are available from `lapis.spec`:

$dual_code{
lua = [[local spec = require("lapis.spec")]],
moon = [[spec = require "lapis.spec"]]
}

### `use_test_env(env_name="test")`

Sets the Lapis environment to `env_name` for the duration of the specs within
the current `describe` block. This is only necessary if you are using an
environment other than the one detected automatically.

$dual_code{
lua = [[
local use_test_env = require("lapis.spec").use_test_env

describe("my site", function()
  use_test_env()
  -- write some tests here
end)
]],
moon = [[
import use_test_env from require "lapis.spec"

describe "my site", ->
  use_test_env!
  -- write some tests here
]]
}

### `running_in_test()`

Returns the name of the test harness if the code is currently running within a
test environment, otherwise returns `false`. This is used internally by Lapis
to determine if the default environment should be `test` instead of
`development`.

Currently supports detection of [Busted][].

$dual_code{
lua = [[
local spec = require("lapis.spec")

if spec.running_in_test() then
  print("Running in test: " .. spec.running_in_test())
else
  print("Not running in test")
end
]],
moon = [[
import running_in_test from require "lapis.spec"

if running_in_test!
  print "Running in test: #{running_in_test!}"
else
  print "Not running in test"
]]
}

 [Busted]: https://lunarmodules.github.io/busted/
