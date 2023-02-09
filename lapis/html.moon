
import concat, insert from table

import type, pairs, ipairs, tostring, getmetatable,
  setmetatable, table from _G

unpack = unpack or table.unpack

import getfenv, setfenv from require "lapis.util.fenv"

import locked_fn, release_fn from require "lapis.util.functions"

CONTENT_FOR_PREFIX = "_content_for_"

escape_patt = do
  punct = "[%^$()%.%[%]*+%-?]"
  (str) ->
    (str\gsub punct, (p) -> "%"..p)

html_escape_entities = {
  ['&']: '&amp;'
  ['<']: '&lt;'
  ['>']: '&gt;'
  ['"']: '&quot;'
  ["'"]: '&#039;'
}

html_unescape_entities = {}
for key,value in pairs html_escape_entities
  html_unescape_entities[value] = key

html_escape_pattern = "[" .. concat([escape_patt char for char in pairs html_escape_entities]) .. "]"

escape = (text) ->
  (text\gsub html_escape_pattern, html_escape_entities)

unescape = (text) ->
  (text\gsub "(&[^&]-;)", (enc) ->
    decoded = html_unescape_entities[enc]
    decoded if decoded else enc)

void_tags = {
  "area"
  "base"
  "br"
  "col"
  "command"
  "embed"
  "hr"
  "img"
  "input"
  "keygen"
  "link"
  "meta"
  "param"
  "source"
  "track"
  "wbr"
}

for tag in *void_tags
  void_tags[tag] = true

------------------

classnames = (t) ->
  if type(t) == "string"
    return t

  ccs = for k,v in pairs t
    if type(k) == "number"
      continue if v == ""
      if type(v) == "table"
        classnames v
      else
        tostring v
    else
      continue unless v
      k

  table.concat ccs, " "

element_attributes = (buffer, t) ->
  return unless type(t) == "table"

  for k,v in pairs t
    if type(k) == "string" and not k\match "^__"
      vtype = type(v)
      if vtype == "boolean"
        if v
          buffer\write " ", k
      else
        if vtype == "table" and k == "class"
          v = classnames v
          continue if v == ""
        else
          v = tostring v

        buffer\write " ", k, "=", '"', escape(v), '"'
  nil

element = (buffer, name, attrs, ...) ->
  with buffer
    \write "<", name
    element_attributes(buffer, attrs)
    if void_tags[name]
      -- check if it has content
      has_content = false
      for thing in *{attrs, ...}
        t = type thing
        switch t
          when "string"
            has_content = true
            break
          when "table"
            if thing[1]
              has_content = true
              break

      unless has_content
        \write "/>"
        return

    \write ">"
    \write_escaped attrs, ...
    \write "</", name, ">"

  return -- return nothing

class Buffer
  builders: {
    html_5: (...) ->
      raw '<!DOCTYPE HTML>'
      if type((...)) == "table"
        html ...
      else
        html lang: "en", ...
  }

  new: (@buffer) =>
    @old_env = {}
    @i = #@buffer
    @make_scope!

  with_temp: (fn) =>
    old_i, old_buffer = @i, @buffer
    @i = 0
    @buffer = {}
    fn!
    with @buffer
      @i, @buffer = old_i, old_buffer

  make_scope: =>
    @scope = setmetatable { [Buffer]: true }, {
      __index: (scope, name) ->
        handler = switch name
          when "widget"
            @\render_widget
          when "render"
            @\render
          when "capture"
            (fn) -> table.concat @with_temp fn
          when "element"
            (...) -> element @, ...
          when "text"
            @\write_escaped
          when "raw"
            @\write

        unless handler
          default = @old_env[name]
          return default unless default == nil

        unless handler
          builder = @builders[name]
          unless builder == nil
            handler = (...) -> @call builder, ...

        unless handler
          handler = (...) -> element @, name, ...

        scope[name] = handler
        handler
    }

  render: (mod_name, ...) =>
    widget = require mod_name
    @render_widget widget ...

  render_widget: (w) =>
    -- instantiate widget if it's a class
    if w.__init and w.__base
      w = w!

    if current = @widget
      w\_inherit_helpers current

    w\render @

  call: (fn, ...) =>
    env = getfenv fn
    if env == @scope
      return fn!

    before = @old_env

    @old_env = env
    clone = locked_fn fn
    setfenv clone, @scope
    out = {clone ...}

    release_fn clone
    @old_env = before
    unpack out

  write_escaped: (thing, next_thing, ...) =>
    switch type thing
      when "string"
        @write escape thing
      when "table"
        for chunk in *thing
          @write_escaped chunk
      else
        @write thing

    if next_thing -- keep the tail call
      @write_escaped next_thing, ...

  write: (thing, next_thing, ...) =>
    switch type thing
      when "string"
        @i += 1
        @buffer[@i] = thing
      when "number"
        @write tostring thing
      when "nil"
        nil -- ignore
      when "table"
        for chunk in *thing
          @write chunk
      when "function"
        @call thing
      else
        error "don't know how to handle: " .. type(thing)

    if next_thing -- keep tail call
      @write next_thing, ...

html_writer = (fn) ->
  (buffer) -> Buffer(buffer)\write fn

render_html = (fn) ->
  buffer = {}
  html_writer(fn) buffer
  concat buffer

-- this is a unique identifier to store the helper chain on a widget
HELPER_KEY = setmetatable {}, __tostring: -> "::helper_key::"

is_mixins_class = (cls) ->
  rawget(cls, "_mixins_class") == true

-- ensures that all methods are called in the buffer's scope
class Widget
  @__inherited: (cls) =>
    cls.__base.__call = (...) => @render ...

  -- get the class where mixins can be inserted
  -- will inject a class one above the current class in the inheritance
  -- hierarchy. If a mixins class has already been injected then it will be returned
  -- returns MixinClass, created(boolean)
  @get_mixins_class: (model) ->
    parent = model.__parent
    unless parent
      error "model does not have parent class"

    -- if class has already been injected, return it
    if is_mixins_class parent
      return parent, false

    mixins_class = class extends model.__parent
      @__name: "#{model.__name}Mixins"
      @_mixins_class: true

    model.__parent = mixins_class
    setmetatable model.__base, mixins_class.__base
    mixins_class, true

  @extend: (name, tbl) =>
    lua = require "lapis.lua"

    switch type(name)
      when "table", "function"
        tbl = name
        name = nil

    if type(tbl) == "function"
      tbl = { content: tbl }

    class_fields = { }

    cls = lua.class name or "ExtendedWidget", tbl, @
    cls, cls.__base

  @include: (other_cls) =>
    other_cls, other_cls_name = if type(other_cls) == "string"
      require(other_cls), other_cls

    if @ == Widget
      error "You attempted to call call Widget:include on the read-only Widget base class. You must create a sub-class to use include"

    -- This works because include adds inheritance chain recursively depth
    -- first, and it will hit Widget form parents
    if other_cls == Widget
      error "Your widget tried to include a class that extends from Widget. An included class should be a plain class and not another widget"

    mixins_class = @get_mixins_class!

    -- if there is a parent, do it first
    -- note: this will flatten the inheritance chain, so super semantics are lost for mixed in methods!
    if other_cls.__parent
      @include other_cls.__parent

    unless other_cls.__base
      error "Expecting a class when trying to include #{other_cls_name or other_cls} into #{@__name}"

    -- copy over all instance methods
    for k,v in pairs other_cls.__base
      continue if k\match("^__")
      mixins_class.__base[k] = v

    true

  new: (opts) =>
    -- copy in options
    if opts
      for k,v in pairs opts
        if type(k) == "string"
          @[k] = v

  _set_helper_chain: (chain) => rawset @, HELPER_KEY, chain
  _get_helper_chain: => rawget @, HELPER_KEY

  _find_helper: (name) =>
    if chain = @_get_helper_chain!
      for h in *chain
        helper_val = h[name]
        if helper_val != nil
          -- call functions in scope of helper
          value = if type(helper_val) == "function"
            (w, ...) -> helper_val h, ...
          else
            helper_val

          return value

  _inherit_helpers: (other) =>
    @_parent = other
    -- add helpers from parents
    if other_helpers = other\_get_helper_chain!
      for helper in *other_helpers
        @include_helper helper

  -- insert table onto end of helper_chain
  include_helper: (helper) =>
    if helper_chain = @[HELPER_KEY]
      insert helper_chain, helper
    else
      @_set_helper_chain { helper }
    nil

  content_for: (name, val) =>
    request = @.get_request and @get_request!
    unless request
      error "content_for called on a widget without a Request in the helper chain. content_for is only available in a request lifecycle"

    if val == nil
      -- No value provided, write the current value to the buffer
      @_buffer\write request[CONTENT_FOR_PREFIX .. name]
      return

    -- evaluate value to string
    val = switch type(val)
      when "string"
        escape val
      when "function"
        getfenv(val).capture val
      else
        error "Got unknown type for content_for value: #{type val}"

    request.__class.support.append_content_for request, name, val
    return

  has_content_for: (name) =>
    request = @.get_request and @get_request!
    return false unless request
    not not request[CONTENT_FOR_PREFIX .. name]

  content: => -- implement me

  render_to_string: (...) =>
    buffer = {}
    @render buffer, ...
    concat buffer

  render_to_file: (file, ...) =>
    opened_file = false

    file = if type(file) == "string"
      opened_file = true
      assert io.open file, "w"

    buffer = setmetatable {}, {
      __newindex: (key, val) =>
        file\write val
        true
    }

    @render buffer, ...

    if opened_file
      file\close!

    true



  render: (buffer, ...) =>
    @_buffer = if buffer.__class == Buffer
      buffer
    else
      Buffer buffer

    old_widget = @_buffer.widget
    @_buffer.widget = @

    meta = getmetatable @
    index = meta.__index
    index_is_fn = type(index) == "function"

    seen_helpers = {}
    scope = setmetatable {}, {
      __tostring: meta.__tostring
      __index: (scope, key) ->
        value = if index_is_fn
          index scope, key
        else
          index[key]

        -- run method in buffer scope
        if type(value) == "function"
          wrapped = if Widget.__base[key] and key != "content"
            value
          else
            (...) -> @_buffer\call value, ...

          scope[key] = wrapped
          return wrapped

        -- look for helper
        if value == nil and not seen_helpers[key]
          helper_value = @_find_helper key
          seen_helpers[key] = true
          if helper_value != nil
            scope[key] = helper_value
            return helper_value

        value
    }

    setmetatable @, __index: scope
    @content ...
    setmetatable @, meta

    @_buffer.widget = old_widget
    return -- return nothing

{ :Widget, :Buffer, :html_writer, :render_html, :escape, :unescape, :classnames, :element, :is_mixins_class, :CONTENT_FOR_PREFIX }

