
import insert, concat from table
import escape_pattern from require "lapis.util"

split = (str, delim using escape_pattern) ->
  str ..= delim
  [part for part in str\gmatch "(.-)" .. escape_pattern delim]

-- wrap test based on tokens
wrap_text = (text, indent=0, max_width=80) ->
  width = max_width - indent
  words = split text, " "
  pos = 1
  lines = {}
  while pos <= #words
    line_len = 0
    line = {}
    while true
      word = words[pos]
      break if word == nil
      error "can't wrap text, words too long" if #word > width
      break if line_len + #word > width

      pos += 1
      insert line, word
      line_len += #word + 1 -- +1 for the space

    insert lines, concat line, " "

  concat lines, "\n" .. (" ")\rep indent

columnize = (rows, indent=2, padding=4, wrap=true) ->
  max = 0
  max = math.max max, #row[1] for row in *rows

  left_width = indent + padding + max

  formatted = for row in *rows
    padd = (max - #row[1]) + padding
    concat {
      (" ")\rep indent
      row[1]
      (" ")\rep padd
      wrap and wrap_text(row[2], left_width) or row[2]
    }

  concat formatted, "\n"

random_string = do
  math.randomseed os.time!
  import random from math
  random_char = ->
    switch random 1,3
      when 1
        random 65, 90
      when 2
        random 97, 122
      when 3
        random 48, 57

  (length) ->
    string.char unpack [ random_char! for i=1,length ]

get_free_port = ->
  socket = require "socket"

  sock = socket.bind "*", 0
  _, port = sock\getsockname!
  sock\close!

  port

default_environment = do
  _env = nil
  ->
    if _env == nil
      _env = "development"
      pcall -> _env = require "lapis_environment"

    _env

if ... == "test"
  print columnize {
    {"hello", "here is some info"}
    {"what is going on", "this is going to be a lot of text so it wraps around the end"}
    {"this is something", "not so much here"}
    {"else", "yeah yeah yeah not so much okay goodbye"}
  }

{ :columnize, :split, :random_string, :get_free_port, :default_environment }
