
-- Note: until tableshape is made a dependency of lapis, do not require it here
-- on the top level to avoid breaking existing users of these functions

import insert from table

unpack = unpack or table.unpack

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

  matches_pattern: (input, pattern) ->
    match = type(input) == "string" and input\match(pattern) or nil
    match != nil, "%s is not the right format"

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

  test: (input, fn) ->
    fn input
}

test_input = (input, func, args) ->
  fn = assert validate_functions[func], "Missing validation function #{func}"
  args = {args} if type(args) != "table"
  fn input, unpack args

validate = (object, validations, opts={}) ->
  errors = {}
  for v in *validations
    key = v[1]
    error_msg = v[2]

    input = object[key]

    if v.optional
      continue unless validate_functions.exists input

    -- TODO: this processes validations in no particular order, which can be bad for tests
    for fn, args in pairs v
      continue if fn == "optional"
      continue unless type(fn) == "string"

      success, msg = test_input input, fn, args
      unless success
        if opts.keys and opts.keys == true
          errors[key] = (error_msg or msg)\format key
        else
          insert errors, (error_msg or msg)\format key
        break

  next(errors) and errors

assert_valid = (object, validations) ->
  -- if validations is like a tableshape checker, call it directly
  if type(validations) == "table" and type(validations.transform) == "function"
    result, err_or_state = validations\transform object

    if result == nil and err_or_state
      errors = if type(err_or_state) == "string"
        {err_or_state}
      else
        err_or_state

      coroutine.yield "error", errors
      error "assert_valid was not captured: #{table.concat errors, ", "}"

    return result, err_or_state

  errors = validate object, validations
  if errors
    coroutine.yield "error", errors
    error "assert_valid was not captured: #{table.concat errors, ", "}"

-- action wrapper that applies validation to params
with_params = (params_spec, fn) ->
  types = require "lapis.validate.types"
  tableshape = require "tableshape"

  t = if tableshape.is_type params_spec
    types.assert_error params_spec
  else
    types.params_shape(params_spec)\assert_errors!

  (...) =>
    params, errs_or_state = t\transform @params
    fn @, params, errs_or_state, ...


{ :validate, :assert_valid, :test_input, :validate_functions, :with_params }
