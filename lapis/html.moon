
module "lapis.html", package.seeall

import concat from table

export html_writer
export Widget

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

  new: (@buffer) ->
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
    @scope = setmetatable {}, {
      __index: (scope, name) ->
        default = @old_env[name]
        return default if default != nil

        builder = @builders[name]
        res = if builder != nil
          (...) -> @call builder, ...
        else
          switch name
            when "capture"
              (fn) -> table.concat @with_temp -> fn!
            when "element"
              (...) -> element @, ...
            when "text"
              @\write_escaped
            when "raw"
              @\write
            else
              (...) -> element @, name, ...

        scope[name] = res
        res
    }

  call: (fn, ...) =>
    env = getfenv fn
    out = nil
    if env == @scope
      out = {fn ...}
    else
      before = @old_env
      @old_env = getfenv fn
      setfenv fn, @scope
      out = {fn ...}
      setfenv fn, @old_env
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

-- ensures that all methods are called in the buffer's scope
class Widget
  @__inherited: (cls) =>
    cls.__base.__call = (...) => @render ...

  content: => -- implement me
  render: (buffer, ...) =>
    b = Buffer(buffer)

    base = getmetatable @
    scope = setmetatable {}, {
      __index: (scope, name) ->
        value = base[name] or rawget @, name

        if type(value) == "function"
          wrapped = (...) -> b\call value, ...
          scope[name] = wrapped
          wrapped
        else
          value
    }

    setmetatable @, __index: scope
    @content ...
    setmetatable @, base
    nil

