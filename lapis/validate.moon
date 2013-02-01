
import insert from table

validate_functions = {
  exists: (input) ->
    input and input != "", "%s must be provided"

  file_exists: (input) ->
    type(input) == "table" and input.filename != "" and input.content != "", "Missing file"

  min_length: (input, len) ->
    #tostring(input or "") >= len, "%s must be at least #{len} chars"

  max_length: (input, len) ->
    #tostring(input or "") <= len, "%s must be at most #{len} chars"

  is_integer: (input) ->
    tostring(input)\match"^%d+$", "%s must be an integer"

  is_color: do
    hex = "[a-fA-f0-9]"
    three = "^##{hex\rep 3}$"
    six = "^##{hex\rep 6}$"
    (input) ->
      input = tostring(input)
      input\match(three) or input\match(six), "%s must be a color"

  equals: (input, value) ->
    input == value, "%s must match"

  one_of: (input, ...) ->
    choices = {...}
    for choice in *choices
      return true if input == choice
    false, "%s must be one of #{table.concat choices, ", "}"
}

test_input = (input, func, args) ->
  fn = assert validate_functions[func], "Missing validation function #{func}"
  args = {args} if type(args) != "table"
  fn input, unpack args

validate = (object, validations) ->
  errors = {}
  for v in *validations
    key = v[1]
    input = object[key]

    if v.optional
      continue unless validate_functions.exists input

    v.optional = nil

    for fn, args in pairs v
      continue unless type(fn) == "string"
      success, msg = test_input input, fn, args
      unless success
        insert errors, msg\format key
        break

  next(errors) and errors

assert_valid = (object, validations) ->
  errors = validate object, validations
  coroutine.yield "error", errors if errors

if ... == "test"
  require "moon"

  o = {
    age: ""
    name: "abc"
    height: "12234234"
  }

  moon.p validate o, {
    { "age", exists: true }
    { "name", exists: true }
  }

  moon.p validate o, {
    { "name", exists: true, min_length: 4 }
    { "age", min_length: 4 }
    { "height", max_length: 5 }
  }

  moon.p validate o, {
    { "height", is_integer: true }
    { "name", is_integer: true }
    { "age", is_integer: true }
  }


  moon.p validate o, {
    { "height", min_length: 4 }
  }

  moon.p validate o, {
    { "age", optional: true, max_length: 2 }
    { "name", optional: true, max_length: 2 }
  }

  moon.p validate o, {
    { "name", one_of: {"cruise", "control" } }
  }

  moon.p validate o, {
    { "name", one_of: {"bcd", "abc" } }
  }



{ :validate, :assert_valid, :test_input }
