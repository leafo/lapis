{
  title: "HTML Generation"
}
<div class="override_lang"></div>

# HTML Generation

This guide is focused on using builder syntax in Lua/MoonScript to generate
HTML. If you're interested in a more traditional templating system see the
[etlua Templates guide]($root/reference/etlua_templates.html).
This mechanism for generating HTML code is mainly intended to be used with
Moonscript, but it can also be used in Lua code.


## HTML Builder Syntax

HTML templates can be written directly as MoonScript (or Lua) code. This is a
very powerful feature (inspired by [Erector](http://erector.rubyforge.org/))
that gives us the ability to write templates with high composability and also
all the features of MoonScript or Lua. No need to learn a separate templating
language, you can use the full power of the language you're already using.

In the context of a HTML renderer, the environment exposes functions that
create HTML tags. The tag builder functions are generated on the fly as you
call them via a custom function environment. The output of these functions is
written into a buffer that is compiled in the end and returned as the result

Here are some examples of the HTML generation:

```moon
div!                -- <div></div>
b "Hello World"     -- <b>Hello World</b>
div "hi<br/>"       -- <div>hi&lt;br/&gt;</div>
text "Hi!"          -- Hi!
raw "<br/>"         -- <br/>

element "table", width: "100%", ->  -- <table width="100%"></table>

div class: "footer", "The Foot"     -- <div class="footer">The Foot</div>

input required: true                -- <input required/>

div ->                              -- <div>Hey</div>
  text "Hey"

div class: "header", ->             -- <div class="header"><h2>My Site</h2>
  h2 "My Site"                      --    <p>Welcome!</p></div>
  p "Welcome!"
```

The `element` function is a special builder that takes the name of tag to
generate as the first argument followed by any attributes and content.

The HTML builder methods have lower precedence than any existing variables, so
if you have a variable named `div` and you want to make a `<div>` tag you'll
need to call `element "div"`.

> If you want to create a `<table>` or `<select>` tag you'll need to use
> `element` because Lua uses those names in the built-in modules.

All strings passed to the HTML builder functions (attribute names, values, or
tag contents) are escaped automatically. You never have to worry about
introducing any cross site scripting vulnerabilities.

### Special attributes

The `class` attribute can be passed as a table, and the class list will be
constructed from it. The table can contain either array element, or hash
elements:

```moon
div {
  class: {"one", "two", three: false, four: true}
}, "Hello world!"
```

Will generate:

```html
<div class="one two four">Hello world!</div>
```

This conversion is done by the `html.classnames` function described below.

### Helper functions

In the scope of a HTML builder function, in addition to the auto generated
functions for writing HTML tags, the following functions are also available:

* `raw(str)` -- outputs the argument, a string, directly to the buffer without escaping.
* `capture(func)` -- executes the function argument in the context of the HTML builder environment, returns the compiled result as a string instead of writing to buffer.
* `text(args)` -- outputs the argument to the buffer, escaping it if it's a string. If it's a function, it executes the function in HTML builder environment. If it's a table, it writes each item in the table
* `widget(some_widget)` -- renders another widget in the current output buffer. Automatically passes the enclosing context. The widget can either be an instance of a widget, or a widget class. If a class is provided, then an instance with no arguments is created.
* `render(template_name)` -- renders another widget or view by the module name. Lets you render etlua templates from inside builder

## HTML In Actions

If we want to generate HTML directly in our action we can use the `@html`
method:

```moon
class MyApp extends lapis.Application
  "/": =>
    @html ->
      h1 class: "header", "Hello"
      div class: "body", ->
        text "Welcome to my site!"
```

The environment of the function passed to `@html` is set to one that support
the HTML builder functions described above. The return value of the `@html`
method is the generated HTML as a string. Returning this from the action allows
us to render send it right to the browser

## HTML Widgets

The preferred way to write HTML is through widgets. Widgets are classes who are
only concerned with outputting HTML. Each method in the widget is executed in
the HTML builder scope that allows you to use the syntax described above to
write HTML to the response buffer.

When Lapis loads a widget automatically it does it by package name. For
example, if it was loading the widget for the name `"index"` it would try to
load the module `views.index`, and the result of that module should be the
widget.

This is what a widget looks like:

```moon
-- views/index.moon
import Widget from require "lapis.html"

class Index extends Widget
  content: =>
    h1 class: "header", "Hello"
    div class: "body", ->
      text "Welcome to my site!"
```


> The name of the widget class is insignificant, but it's worth making one
> because some systems can auto-generate encapsulating HTML named after the
> class.

### Rendering A Widget From An Action

The `render` option key is used to render a widget. For example you can render
the `"index"` widget from our action by returning a table with render set to
the name of the widget:

```moon
"/": =>
  render: "index"
```

If the action has a name, then we can set render to `true` to load the widget
with the same name as the action:

```moon
[index: "/"]: =>
  render: true
```

By default `views.` is prepended to the widget name and then loaded
using Lua's `require` function. The `views` prefix can be customized by
overwriting the `views_prefix` member of your application subclass:

```moon
class Application extends lapis.Application
  views_prefix: "app_views"

  -- will use "app_views.home" as the view
  [home: "/home"]: => render: true
```

### Passing Data To A Widget

Any `@` variables set in the action can be accessed in the widget. Additionally
any of the helper functions like `@url_for` are also accessible.

```moon
-- app.moon
class App extends lapis.Application
  [index: "/"]: =>
    @page_title = "Welcome To My Page"
    render: true
```

```moon
-- views/index.moon
import Widget from require "lapis.html"

class Index extends Widget
  content: =>
    h1 class: "header", @page_title
    div class: "body", ->
      text "Welcome to my site!"
```

### Rendering Widgets Manually

Widgets can also be rendered manually by instantiating them and calling the
`render_to_string` method.

```moon
Index = require "views.index"

widget = Index page_title: "Hello World"
print widget\render_to_string!
```

If you want to use helpers like `@url_for` you also need to include them in the
widget instance. Any object can be included as a helper, and its methods will
be made available inside of the widget.

```moon
html = require "lapis.html"
class SomeWidget extends html.Widget
  content: =>
    a href: @url_for("test"), "Test Page"

class extends lapis.Application
  [test: "/test_render"]: =>
    widget = SomeWidget!
    widget\include_helper @
    widget\render_to_string!
```

You should avoid rendering widgets manually when possible. When in an action
use the `render` [request option](#request-object-request-options). When in
another widget use the `widget` helper function. Both of these methods will
ensure the same output buffer is shared to avoid unnecessary string
concatenations.

## Layouts

Whenever an action is rendered normally the result is inserted into the
current layout. The layout is just another widget, but it is used across many
pages. Typically this is where you would put your `<html>` and `<head>` tags.

Lapis comes with a default layout that looks like this:

```moon
html = require "lapis.html"

class DefaultLayout extends html.Widget
  content: =>
    html_5 ->
      head -> title @title or "Lapis Page"
      body -> @content_for "inner"
```

Use this as a starting point for creating your own layout. The content of your
page will be injected in the location of the call to `@content_for "inner"`.

We can specify the layout for an entire application or specify it for a
specific action. For example, if we have our new layout in `views/my_layout.moon`

```moon
class extends lapis.Application
  layout: require "views.my_layout"
```

If we want to set the layout for a specific action we can provide it as part of
the action's return value.

```moon
class extends lapis.Application
  -- the following two have the same effect
  "/home1": =>
    layout: "my_layout"

  "/home2": =>
    layout: require "views.my_layout"

  -- this doesn't use a layout at all
  "/no_layout": =>
    layout: false, "No layout rendered!"

```

As demonstrated in the example, passing false will prevent any layout from
being rendered.

## Widget Methods

```moon
import Widget from require "lapis.html"
```

When sub-classing a widget, take care not to override these methods if you don't
intend to change the default behavior.

### `Widget([opts])`

The default constructor of the widget class will copy over every field from the
`opts` argument to `self`, if the `opts` argument is provided. You can use this
to set render-time parameters or override methods.

```moon
class SomeWidget extends html.Widget
  content: =>
    div "Hello ", @name

widget = SomeWidget name: "Garf"
print widget\render_to_string! --> <div>Hello Garf</div>
```

It is safe to override the constructor and not call `super` if you want to change
the initialization conditions of your widget.

### `Widget:include(other_class)`

Class method that copies the methods from another class into this widget.
Useful for mixin in shared functionality across multiple widgets.

```moon
class MyHelpers
  item_list: (items) =>
    ul ->
      for item in *items
        li item

class SomeWidget extends Widget
  @include MyHelpers

  content: =>
    @item_list {"hello", "world"}
```

### `widget:render_to_string()`

Renders the `content` method of a widget and returns the string result. This
will automatically create a temporary buffer for the duration of the render.
This internally calls `widget.render()` with the temporary buffer.

Keep in mind that widgets must be executed in a special scope to enable the
HTML builder functions to work. It is not possible to call the `content` method
directly on the widget if you wish to render it, you must use this method.

### `widget:render(buffer, ...)`

Renders the `content` method of the widget to the provided buffer. Under normal
circumstances it is not necessary to use this method directly. However, it's
worth noting it exists to avoid accidentally overwriting the method when
sub-classing your own widgets.

This method returns nothing.

### `widget:content_for(name, [content])`

`content_for` is used for sending HTML or strings from the view to the layout.
You've probably already seen `@content_for "inner"` if you've looked at
layouts. By default the content of the view is placed in the content block
called `"inner"`.

If `content_for` is called multiple times on the same `name`, the results will be
appended, not overwritten.

You can create arbitrary content blocks from the view by calling `@content_for`
with a name and some content:

```moon
class MyView extends Widget
  content: =>
    @content_for "title", "This is the title of my page!"

    @content_for "footer", ->
      div class: "custom_footer", "The Footer"

```

You can use either strings or builder functions as the content.

To access the content from the layout, call `@content_for` without the content
argument:

```moon
class MyLayout extends Widget
  content: =>
    html ->
      body ->
        div class: "title", ->
          @content_for "title"

        @content_for "inner"
        @content_for "footer"
```

If a string is used as the value of a content block then it will be escaped
before written to the buffer. If you want to insert a raw string then you can
use a builder function in conjunction with the `raw` function:

```moon
@content_for "footer", ->
  raw "<pre>this wont' be escaped</pre>"
```

### `widget:has_content_for(name)`

Checks to see if content for `name` is set.

```moon
class MyView extends Widget
  content: =>
    if @has_content_for "things"
      @content_for "things"
    else
      div ->
        text "default content"
```

## HTML Module

```moon
html = require "lapis.html"
```

### `html.Widget`

The Widget base class for creating templates in code as a class. See the [HTML
Widgets](#html-widgets) for a full guide on using the Widget class.

```lua
local html = require("lapis.html")
local class = require("lapis.lua").class

local IndexPage = class "IndexPage", {
  content = function(self)
    div("Hello!")
  end
}, html.Widget
```

```moon
import Widget from require "lapis.html"

class IndexPage extends Widget
  content: =>
    div "Hello!"
```

### `html.render_html(fn)`

Runs the function, `fn` in the HTML rendering context as described above.
Returns the resulting HTML. The HTML context will automatically convert any
reference to an undefined global variable into a function that will render the
appropriate tag.

```moon
import render_html from require "lapis.html"

print render_html ->
  div class: "item", ->
    strong "Hello!"
```

### `html.escape(str)`

Escapes any HTML special characters in the string. The following are escaped:

 * `&` -- `&amp;`
 * `<` -- `&lt;`
 * `>` -- `&gt;`
 * `"` -- `&quot;`
 * `'` -- `&#039;`

### `html.classnames(t)`

Converts a nested Lua table into a HTML class attribute string. Passing a
string to this function will return the string unmodified.

This function is applied to the value of the class attribute when using the
HTML builder syntax.

$dual_code{[[
classnames({
  "one"
  "two"
  yes: true
  {skipped: false, haveit: true, "", "last"}
}) --> "one two yes haveit last"
]]}


### `html.is_mixins_class(obj)`

Returns `true` if the the argument `obj` is an auto-generated mixin class that
is inserted into the class hierarchy of a widget when `Widget:include` is
called.

```moon
html = require "lapis.html"

class MyHelpers
  say_hi: => div "hi"

class SomeWidget extends html.Widget
  @include MyHelpers
  content: => @say_hi!

print html.is_mixins_class(SomeWidget.__parent) --> true

```
