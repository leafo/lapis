title: HTML Generation
--
<div class="override_lang"></div>

# HTML Generation

This guide is focused on using builder syntax in Lua/MoonScript to generate
HTML. If you're interested in a more traditional templating system see the
[etlua Templates guide]($root/reference/etlua_templates.html).

## HTML In Actions

If we want to generate HTML directly in our action we can use the `@html`
method:

```moon
"/": =>
  @html ->
    h1 class: "header", "Hello"
    div class: "body", ->
      text "Welcome to my site!"
```

HTML templates can be written directly as MoonScript (or Lua) code. This is a
very powerful feature (inspired by [Erector](http://erector.rubyforge.org/))
that gives us the ability to write templates with high composability and also
all the features of MoonScript. No need to learn any goofy templating syntax
with arbitrary restrictions.

The `@html` method overrides the environment of the function passed to it.
Functions that create HTML tags are generated on the fly as you call them. The
output of these functions is written into a buffer that is compiled in the end
and returned as the result of the action.

Here are some examples of the HTML generation:

```moon
div!                -- <div></div>
b "Hello World"     -- <b>Hello World</b>
div "hi<br/>"       -- <div>hi&lt;br/&gt;</div>
text "Hi!"          -- Hi!
raw "<br/>"         -- <br/>

element "table", width: "100%", ->  -- <table width="100%"></table>

div class: "footer", "The Foot"     -- <div class="footer">The Foot</div>

div ->                              -- <div>Hey</div>
  text "Hey"

div class: "header", ->             -- <div class="header"><h2>My Site</h2>
  h2 "My Site"                      --    <p>Welcome!</p></div>
  p "Welcome!"
```

The `element` function is a special builder that takes the name of tag to
generate as the first argument followed by any attributes and content.

The HTML builder methods have lower precedence than any existing variables, so
if you have a variable named `div` and you want to make a `<div>` tag you'll need
to call `element "div"`.

> If you want to create a `<table>` or `<select>` tag you'll need to use `element` because Lua
> uses those names in the built-in modules.

## HTML Widgets

The preferred way to write HTML is through widgets. Widgets are classes who are
only concerned with outputting HTML. They use the same syntax as the `@html`
helper shown above for writing HTML.

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

By default `views.` is appended to the front of the widget name and then loaded
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
-- web.moon
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
`render` method.

```moon
Index = require "views.index"

widget = Index page_title: "Hello World"
print widget\render_to_string!
```

If you want to use helpers like `@url_for` you also need to include them in the
widget instance. Any object can be included as a helper, and it's methods will
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
another widget use the `widget` helper function.

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

### `@@include(other_class)`

Class method that copies the methods from another class into this widget.
Useful for mixin in shared functionality across multiple widgets.

```moon
class MyHelpers
  item_list: (items) =>
    ul ->
      for item in *items
        li item


class SomeWidget extends html.Widget
  @include MyHelpers

  content: =>
    @item_list {"hello", "world"}
```


### `@content_for(name, [content])`

`content_for` is used for sending HTML or strings from the view to the layout.
You've probably already seen `@content_for "inner"` if you've looked at
layouts. By default the content of the view is placed in the content block
called `"inner"`.

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

To access the content from the layout call `@content_for` without the content
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

### `@has_content_for(name)`

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

### `render_html(fn)`

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

### `escape(str)`

Escapes any HTML special characters in the string. The following are escaped:

 * `&` -- `&amp;`
 * `<` -- `&lt;`
 * `>` -- `&gt;`
 * `"` -- `&quot;`
 * `'` -- `&#039;`

