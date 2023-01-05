local insert
insert = table.insert
local unpack = unpack or table.unpack
local validate_functions = {
  exists = function(input)
    return input and input ~= "", "%s must be provided"
  end,
  file_exists = function(input)
    return type(input) == "table" and input.filename ~= "" and input.content ~= "", "Missing file"
  end,
  min_length = function(input, len)
    return #tostring(input or "") >= len, "%s must be at least " .. tostring(len) .. " chars"
  end,
  max_length = function(input, len)
    return #tostring(input or "") <= len, "%s must be at most " .. tostring(len) .. " chars"
  end,
  is_file = function(input)
    return type(input) == "table" and input.filename ~= "" and input.content ~= "", "Missing file"
  end,
  is_integer = function(input)
    return tostring(input):match("^%d+$"), "%s must be an integer"
  end,
  is_color = (function()
    local hex = "[a-fA-f0-9]"
    local three = "^#" .. tostring(hex:rep(3)) .. "$"
    local six = "^#" .. tostring(hex:rep(6)) .. "$"
    return function(input)
      input = tostring(input)
      return input:match(three) or input:match(six), "%s must be a color"
    end
  end)(),
  is_timestamp = function(input)
    local month = input and input:match("^%d+%-(%d+)%-(%d+)%s+(%d+):(%d+):(%d+)$")
    return month ~= nil, "%s is not a valid timestamp"
  end,
  matches_pattern = function(input, pattern)
    local match = type(input) == "string" and input:match(pattern) or nil
    return match ~= nil, "%s is not the right format"
  end,
  equals = function(input, value)
    return input == value, "%s must match"
  end,
  one_of = function(input, ...)
    local choices = {
      ...
    }
    for _index_0 = 1, #choices do
      local choice = choices[_index_0]
      if input == choice then
        return true
      end
    end
    return false, "%s must be one of " .. tostring(table.concat(choices, ", "))
  end,
  type = function(input, kind)
    if type(input) == kind then
      return true
    end
    return false, "%s must be a " .. kind
  end,
  test = function(input, fn)
    return fn(input)
  end
}
local test_input
test_input = function(input, func, args)
  local fn = assert(validate_functions[func], "Missing validation function " .. tostring(func))
  if type(args) ~= "table" then
    args = {
      args
    }
  end
  return fn(input, unpack(args))
end
local validate
validate = function(object, validations, opts)
  if opts == nil then
    opts = { }
  end
  local errors = { }
  for _index_0 = 1, #validations do
    local _continue_0 = false
    repeat
      local v = validations[_index_0]
      local key = v[1]
      local error_msg = v[2]
      local input = object[key]
      if v.optional then
        if not (validate_functions.exists(input)) then
          _continue_0 = true
          break
        end
      end
      for fn, args in pairs(v) do
        local _continue_1 = false
        repeat
          if fn == "optional" then
            _continue_1 = true
            break
          end
          if not (type(fn) == "string") then
            _continue_1 = true
            break
          end
          local success, msg = test_input(input, fn, args)
          if not (success) then
            if opts.keys and opts.keys == true then
              errors[key] = (error_msg or msg):format(key)
            else
              insert(errors, (error_msg or msg):format(key))
            end
            break
          end
          _continue_1 = true
        until true
        if not _continue_1 then
          break
        end
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return next(errors) and errors
end
local assert_valid
assert_valid = function(object, validations)
  if type(validations) == "table" and type(validations.transform) == "function" then
    local result, err_or_state = validations:transform(object)
    if result == nil and err_or_state then
      local errors
      if type(err_or_state) == "string" then
        errors = {
          err_or_state
        }
      else
        errors = err_or_state
      end
      coroutine.yield("error", errors)
      error("assert_valid was not captured: " .. tostring(table.concat(errors, ", ")))
    end
    return result, err_or_state
  end
  local errors = validate(object, validations)
  if errors then
    coroutine.yield("error", errors)
    return error("assert_valid was not captured: " .. tostring(table.concat(errors, ", ")))
  end
end
local with_params
with_params = function(params_spec, fn)
  local types = require("lapis.validate.types")
  local tableshape = require("tableshape")
  local t
  if tableshape.is_type(params_spec) then
    t = types.assert_error(params_spec)
  else
    t = types.params_shape(params_spec):assert_errors()
  end
  return function(self, ...)
    local params, errs_or_state = t:transform(self.params)
    return fn(self, params, errs_or_state, ...)
  end
end
return {
  validate = validate,
  assert_valid = assert_valid,
  test_input = test_input,
  validate_functions = validate_functions,
  with_params = with_params
}
