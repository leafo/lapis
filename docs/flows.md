{
  title: "Flows"
}

# Flows

The `Flow` class is a way of writing a module of methods that operates on some
encapsulated object. You might call it a
[mediator](https://en.wikipedia.org/wiki/Mediator_pattern). We'll call the
encapsulated object the *contained object* in this guide.

Typically we'll use flows to wrap the request object within Lapis, but it's not
a requirement and you can use any Lua object. The flow will proxy method calls
and field reads and assignments back to the contained object.

If this explanation is confusing, don't worry. It's easier to understand a flow
in example. We'll use the `Flow` class standalone to demonstrate how it works.

$dual_code{
lua = [[
local Flow = require("lapis.flow").Flow

local FormatterFlow = Flow:extend({
  format_name = function(self)
    -- self.name and self.age are read from the contained object
    return self.name .. " (age: " .. self.age .. ")"
  end,

  print_greeting = function(self)
    -- self:get_greeting() calls get_greeting on the contained object
    print(self:get_greeting())
  end
})
]],
moon = [[
import Flow from require "lapis.flow"

class FormatterFlow extends Flow
  format_name: =>
    -- @name and @age are read from the contained object
    "#{@name} (age: #{@age})"

  print_greeting: =>
    -- @get_greeting! calls get_greeting on the contained object
    print @get_greeting!
]]
}

The above flow provides a `format_name` method that reads the `name` and `age`
fields from the contained object. When you access a field or call a method on
`self` that doesn't exist on the flow, it is automatically proxied to the
contained object. When calling a method on the contained object, the receiver
is the contained object itself, not the flow.

We can instantiate a flow with an object that provides those fields, then call
the flow's method on the flow instance:

$dual_code{
lua = [[
local obj = {
  name = "Pizza Zone",
  age = "2000 Years",
  get_greeting = function(self)
    -- self will always be obj, not a flow instance, even if called through a
    -- flow
    return "Hello from " .. self.name
  end
}

local flow = FormatterFlow(obj)
print(flow:format_name()) --> "Pizza Zone (age: 2000 Years)"
flow:print_greeting()     --> "Hello from Pizza Zone"
]],
moon = [[
obj = {
  name: "Pizza Zone"
  age: "2000 Years"
  get_greeting: =>
    -- @ will always be obj, not a flow instance, even if called through a
    -- flow
    "Hello from #{@name}"
}

flow = FormatterFlow(obj)
print flow\format_name! --> "Pizza Zone (age: 2000 Years)"
flow\print_greeting!    --> "Hello from Pizza Zone"
]]
}

You can think of a flow as a collection of methods that are designed to operate
on a certain kind of object. Why would we use a flow instead of just making
these methods part of the object's class? A flow lets you encapsulate logic
into a separate namespace. Instead of having classes with many methods, you
split apart your methods into flows and leave the class with a smaller
implementation. This can help your code stay more organized and also make it
easier to unit-test individual code paths without having to mock and entire
request.

## Assigning Fields Within a Flow

If you assign to `self` in a flow it is saved on the flow instance by default.
This can be used for private data specific to that flow. A good example might
be caching the result of an expensive method call.

If you want assignments on `self` to be sent back to the original class then
you can use `expose_assigns`. It's a class property that tells the flow how to
handle assignments to self.

`expose_assigns` can take two types of values:

* `true` -- all assignments are proxied back to the contained object
* An array of strings -- any field name contained in this array is proxied back to the object

Here's an example using an array to selectively expose certain fields:

$dual_code{
lua = [[
local Flow = require("lapis.flow").Flow

local MyFlow = Flow:extend({
  expose_assigns = {"user", "session"},

  setup = function(self)
    self.user = fetch_user()      -- proxied to contained object
    self.session = get_session()  -- proxied to contained object
    self.cache = {}               -- stored on flow instance (private)
  end
})
]],
moon = [[
import Flow from require "lapis.flow"

class MyFlow extends Flow
  @expose_assigns: {"user", "session"}

  setup: =>
    @user = fetch_user!      -- proxied to contained object
    @session = get_session!  -- proxied to contained object
    @cache = {}              -- stored on flow instance (private)
]]
}

This pattern is helpful when you have a Flow operating on a Lapis Request
object where you want to set up fields on the request that may be made
available to views or other parts of the request handler.

## Accessing The Contained Object

The contained object is stored on `self` with the name `_` (an underscore).
Consider it a reserved field for the flow to operate correctly, don't replace
it it, but you can access it.

For example, if you need to access the metatable on the contained object for
some reason:

$dual_code{
lua = [[
local Flow = require("lapis.flow").Flow

local MetatableFlow = Flow:extend({
  get_metatable = function(self)
    return getmetatable(self._)
  end
})

print(MetatableFlow({}):get_metatable())
]],
moon = [[
import Flow from require "lapis.flow"

class MetatableFlow extends Flow
  get_metatable: =>
    getmetatable @_

print MetatableFlow({})\get_metatable!
]]
}

## Organizing Your Application With Flows

In Lapis, an application class is where you define routes and your request
logic. Since there are so many responsibilities it's easy for an application
class to get too large to maintain. A good way of separating concerns is to use
flows. In this case, the contained object will be the request instance. You'll
call the flow from within your application. Because this is a common pattern,
there's a `flow` method on the request object that makes instantiating flows
easy.

In this example, we declare a flow class for handling logging in and
registering on a website. Logging in and registering an account may share code,
so we can use additional flow methods to encapsulate our logic without
repeating ourselves.

From our application we call the flow:

$dual_code{
lua = [[
local Flow = require("lapis.flow").Flow

local AccountsFlow = Flow:extend({
  check_params = function(self)
    -- validate self.params...
  end,

  write_session = function(self, user)
    -- store user in session...
  end,

  login = function(self)
    self:check_params()
    -- load user from database...
    self:write_session(user)
    return { redirect_to = self:url_for("homepage") }
  end,

  register = function(self)
    self:check_params()
    -- create user in database...
    self:write_session(user)
    return { redirect_to = self:url_for("homepage") }
  end
})
]],
moon = [[
import Flow from require "lapis.flow"

class AccountsFlow extends Flow
  check_params: =>
    -- validate @params...

  write_session: (user) =>
    -- store user in session...

  login: =>
    @check_params!
    -- load user from database...
    @write_session user
    redirect_to: @url_for "homepage"

  register: =>
    @check_params!
    -- create user in database...
    @write_session user
    redirect_to: @url_for "homepage"
]]
}

The structure of your application could then be:

$dual_code{
lua = [[
local lapis = require("lapis")
local capture_errors = require("lapis.application").capture_errors

local app = lapis.Application()

app:match("login", "/login", capture_errors(function(self)
  return self:flow("accounts"):login()
end))

app:match("register", "/register", capture_errors(function(self)
  return self:flow("accounts"):register()
end))
]],
moon = [[
class App extends lapis.Application
  [login: "/login"]: capture_errors => @flow("accounts")\login!
  [register: "/register"]: capture_errors => @flow("accounts")\register!
]]
}

## Nested Flows

When you instantiate a flow and pass an existing flow as the argument, the
backing object is passed directly into the new flow. This means that the
current flow's methods are not made available to the new flow.

$dual_code{
lua = [[
local Flow = require("lapis.flow").Flow

local my_object = { color = "blue" }

local FlowA = Flow:extend({})
local FlowB = Flow:extend({})

local flow_a = FlowA(my_object)
local flow_b = FlowB(flow_a)  -- passing flow_a, not my_object

-- flow_a and flow_b both point to my_object
assert(flow_a._ == my_object)
assert(flow_b._ == my_object)
]],
moon = [[
import Flow from require "lapis.flow"

my_object = { color: "blue" }

class FlowA extends Flow
class FlowB extends Flow

flow_a = FlowA my_object
flow_b = FlowB flow_a  -- passing flow_a, not my_object

-- flow_a and flow_b both point to my_object
assert(flow_a._ == my_object)
assert(flow_b._ == my_object)
]]
}

## Utility Functions

### `is_flow_class(cls)`

The `is_flow_class` function checks if a class or instance is a Flow:

$dual_code{
lua = [[
local Flow = require("lapis.flow").Flow
local is_flow_class = require("lapis.flow").is_flow_class

MyFlow = Flow:extend({})
some_object = {}

is_flow_class(MyFlow) --> true
is_flow_class(some_object) --> false
]],
moon = [[
import Flow, is_flow_class from require "lapis.flow"

class MyFlow extends Flow
some_object = {}

is_flow_class MyFlow --> true
is_flow_class some_object --> false
]]
}
