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
import Flow from require "lapis.flows"

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
import Flow from require "lapis.flows"

class StringFlow extends Flow
  address: =>
    tostring @_

print StringFlow({})\address!
```

## Organizing Your Application With Flows

## Nested Flows

When you instantiate a flow from within a flow, the backing object is passed to
the new flow to be wrapped. This means that the current flow's methods are not
made available to the new flow.

```lua
-- todo
```


```moon
my_object = { color: "blue" }

class SubFlow extends Flow
  check_object: =>
    assert my_object == @_

class OuterFlow extends Flow
  get_sub: => SubFlow @

OuterFlow(my_object)\get_sub!\check_object!
```

