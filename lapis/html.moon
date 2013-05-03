
import concat from table

_G = _G

punct = "[%^$()%.%[%]*+%-?]"
escape_patt = (str) ->
  (str\gsub punct, (p) -> "%"..p)

html_encode_entities = {
  ['&']: '&amp;'
  ['<']: '&lt;'
  ['>']: '&gt;'
  ['"']: '&quot;'
  ["'"]: '&#039;'
}

html_decode_entities = {}
for key,value in pairs html_encode_entities
  html_decode_entities[value] = key

html_encode_pattern = "[" .. concat([escape_patt char for char in pairs html_encode_entities]) .. "]"

encode = (text) ->
  (text\gsub html_encode_pattern, html_encode_entities)

escape = encode

decode = (text) ->
  (text\gsub "(&[^&]-;)", (enc) ->
    decoded = html_decode_entities[enc]
    decoded if decoded else enc)

unescape = decode

strip_tags = (html) ->
  html\gsub "<[^>]+>", ""

------------------

element_attributes = (buffer, t) ->
  return unless type(t) == "table"

  padded = false
  for k,v in pairs t
    if type(k) == "string" and not k\match "^__"
      if not padded
        buffer\write " "
        padded = true
      buffer\write k, "=", '"', escape(tostring(v)), '"'
  nil

element = (buffer, name, ...) ->
  inner = {...}
  with buffer
    \write "<", name
    element_attributes(buffer, inner[1])
    \write ">"
    \write_escaped inner
    \write "</", name, ">"

class Buffer
  builders: {
    html_5: (...) ->
      raw '<!DOCTYPE HTML>'
      raw '<html lang="en">'
      text ...
      raw '</html>'
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
            (w) -> w\render @
          when "capture"
            (fn) -> table.concat @with_temp -> fn!
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

  call: (fn, ...) =>
    env = getfenv fn
    out = nil
    if env == @scope
      out = {fn ...}
    else
      before = @old_env
      -- env[Buffer] is true with we have a broken function
      -- a function that errored out mid way through a previous render
      @old_env = env[Buffer] and _G or env
      setfenv fn, @scope
      out = {fn ...}
      setfenv fn, env
      @old_env = before

    unpack out

  write_escaped: (...) =>
    for thing in *{...}
      switch type thing
        when "string"
          @write escape thing
        when "table"
          for chunk in *thing
            @write_escaped chunk
        else
          @write thing
    nil

  write: (...) =>
    for thing in *{...}
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
    nil

html_writer = (fn) ->
  (buffer) -> Buffer(buffer)\write fn

render_html = (fn) ->
  buffer = {}
  html_writer(fn) buffer
  concat buffer

helper_key = setmetatable {}, __tostring: -> "::helper_key::"
-- ensures that all methods are called in the buffer's scope
class Widget
  @__inherited: (cls) =>
    cls.__base.__call = (...) => @render ...

  new: (opts) =>
    -- copy in options
    if opts
      @[k] = v for k,v in pairs opts

  _set_helper_chain: (chain) => rawset @, helper_key, chain
  _get_helper_chain: => rawget @, helper_key

  -- insert table onto end of helper_chain
  include_helper: (helper) =>
    if helper_chain = @[helper_key]
      insert helper_chain, helper
    else
      @_set_helper_chain { helper }
    nil

  content_for: (name) =>
    @_buffer\write_escaped @[name]

  content: => -- implement me
  render: (buffer, ...) =>
    @_buffer = if buffer.__class == Buffer
      buffer
    else
      Buffer buffer

    meta = getmetatable @
    index = meta.__index
    index_is_fn = type(index) == "function"

    seen_helpers = {}
    helper_chain = @_get_helper_chain!
    scope = setmetatable {}, {
      __tostring: meta.__tostring
      __index: (scope, key) ->
        value = if index_is_fn
          index scope, key
        else
          index[key]

        -- run method in buffer scope
        if type(value) == "function"
          wrapped = (...) -> @_buffer\call value, ...
          scope[key] = wrapped
          return wrapped

        -- look for helper
        if value == nil and not seen_helpers[key] and helper_chain
          for h in *helper_chain
            helper_val = h[key]
            if helper_val
              -- call functions in scope of helper
              value = if type(helper_val) == "function"
                (w, ...) -> helper_val h, ...
              else
                helper_val

              seen_helpers[key] = true
              scope[key] = value
              return value

        value
    }

    setmetatable @, __index: scope
    @content ...
    setmetatable @, meta
    nil

{ :Widget, :html_writer, :render_html }

