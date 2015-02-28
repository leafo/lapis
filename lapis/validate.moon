
import insert from table

validate_functions = {
  exists: (input) ->
    input and input != "", "%s must be provided"

  -- TODO: remove this in favor of is_file
  file_exists: (input) ->
    type(input) == "table" and input.filename != "" and input.content != "", "Missing file"

  min_length: (input, len) ->
    #tostring(input or "") >= len, "%s must be at least #{len} chars"

  max_length: (input, len) ->
    #tostring(input or "") <= len, "%s must be at most #{len} chars"

  is_file: (input) ->
    type(input) == "table" and input.filename != "" and input.content != "", "Missing file"

  is_integer: (input) ->
    tostring(input)\match"^%d+$", "%s must be an integer"

  is_color: do
    hex = "[a-fA-f0-9]"
    three = "^##{hex\rep 3}$"
    six = "^##{hex\rep 6}$"
    (input) ->
      input = tostring(input)
      input\match(three) or input\match(six), "%s must be a color"

  is_timestamp: (input) ->
    month = input and input\match "^%d+%-(%d+)%-(%d+)%s+(%d+):(%d+):(%d+)$"
    month != nil, "%s is not a valid timestamp"

  equals: (input, value) ->
    input == value, "%s must match"

  one_of: (input, ...) ->
    choices = {...}
    for choice in *choices
      return true if input == choice
    false, "%s must be one of #{table.concat choices, ", "}"

  type: (input, kind) ->
    return true if type(input) == kind
    false, "%s must be a " .. kind
}

test_input = (input, func, args) ->
  fn = assert validate_functions[func], "Missing validation function #{func}"
  args = {args} if type(args) != "table"
  fn input, unpack args

validate = (object, validations) ->
  errors = {}
  for v in *validations
    key = v[1]
    error_msg = v[2]

    input = object[key]

    if v.optional
      continue unless validate_functions.exists input

    v.optional = nil

    for fn, args in pairs v
      continue unless type(fn) == "string"
      success, msg = test_input input, fn, args
      unless success
        insert errors, (error_msg or msg)\format key
        break

  next(errors) and errors

assert_valid = (object, validations) ->
  errors = validate object, validations
  coroutine.yield "error", errors if errors

{ :validate, :assert_valid, :test_input, :validate_functions }
