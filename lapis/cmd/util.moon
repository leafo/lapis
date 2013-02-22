
import insert, concat from table
import escape_pattern from require "lapis.util"

split = (str, delim using nil) ->
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

columnize = (rows, indent=2, padding=4) ->
  max = 0
  max = math.max max, #row[1] for row in *rows

  left_width = indent + padding + max

  formatted = for row in *rows
    padd = (max - #row[1]) + padding
    concat {
      (" ")\rep indent
      row[1]
      (" ")\rep padd
      wrap_text row[2], left_width
    }

  concat formatted, "\n"

if ... == "test"
  print columnize {
    {"hello", "here is some info"}
    {"what is going on", "this is going to be a lot of text so it wraps around the end"}
    {"this is something", "not so much here"}
    {"else", "yeah yeah yeah not so much okay goodbye"}
  }

{ :columnize, :split }
