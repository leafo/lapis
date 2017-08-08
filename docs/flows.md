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

```lua
-- todo
```

```moon
import Flow from require "lapis.flow"

class FormatterFlow extends Flow
  format_name: =>
    "#{@name} (age: #{@age})"

```

The above flow provides a `format_name` method that reads the `name` and `age`
fields. We can instantiate a flow with an object that provides those fields,
then call that method on the flow instance:

```lua
-- todo
```

```moon
obj = {
  name: "Pizza Zone"
  age: "2000 Years"
}

print FormatterFlow(obj)\format_name!
```

You can think of a flow of a collection of methods that are designed to operate
on a certain kind of object. Why would we use a flow instead of just making
these methods part of the objects class? A flow lets you encapsulate logic into
a separate namespace. Instead of having classes with many methods, you split
apart your methods into flows and leave the class with a smaller
implementation.

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

## Accessing The Contained Object

The contained object is stored on `self` with the name `_` (an underscore). You
should avoid writing to this field since the flow expects it to exist.

For example, you can call `tostring` on the contained object like this:

```lua
-- todo
```

```moon
import Flow from require "lapis.flow"

class StringFlow extends Flow
  address: =>
    tostring @_

print StringFlow({})\address!
```

## Organizing Your Application With Flows

in lapis, an application class is where you define routes and your request
logic. since there are so many responsibilities it easy for an applicatoin
class to get too large to maintain. a good way of separating concerns is to use
flows. In this case, the contained object will be the request instance. You'll
call the flow from within your application. Because this is a common pattern,
there's a `flow` method on the request object that makes instantiating flows
easy.

In this example we declare a flow class for handling logging in and registering
on a website. From our applicaton we call the flow:

```moon
import Flow from require "lapis.flow"
class AccountsFlow extends Flow
  login: =>
    -- check parameters
    -- create the session
    redirect_to: @url_for("homepage")

  register: =>
    -- check parameters
    -- create the account, or return error
    -- create a session
    redirect_to: @url_for("homepage")
```

The structure of your application could then be:

```moon
class App extends lapis.Application
  [login: "/login"]: capture_errors => @flow("accounts")\login!
  [register: "/register"]: capture_errors => @flow("accounts")\register!
```

## Nested Flows

When you instantiate a flow from within a flow, the backing object is wrapped
directly by the the new flow. This means that the current flow's methods are
not made available to the new flow.

```lua
-- todo
```


```moon
my_object = { color: "blue" }

class SubFlow extends flow
  check_object: =>
    assert my_object == @_

class OuterFlow extends flow
  get_sub: => subflow @

OuterFlow(my_object)\get_sub!\check_object!
```

