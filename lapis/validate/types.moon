
import types, BaseType, FailedTransform from require "tableshape"
import instance_of from require "tableshape.moonscript"

import yield_error from require "lapis.application"

indent = (str) ->
  rows = [s for s in str\gmatch "[^\n]+"]
  table.concat [idx > 1 and "  #{r}" or r for idx, r in ipairs rows], "\n"

-- wraps a type to throw error using yield_error. If error is already an array
-- of errors (since it came from ValidateParamsType) then that is yielded
-- directly
class AssertErrorType extends types.assert
  assert: (first, msg, ...) ->
    unless first
      -- support passing errors object through unchanged
      if type(msg) == "table"
        coroutine.yield "error", msg
      else
        yield_error msg or "unknown error"

      assert first, msg, ...

    first, msg, ...

-- type that can validate params object, returning only the fields that are specified
-- this is different than types.shape because it:
-- * takes a ordered list of field names that can apply customizations
-- * aggregates all errors into a table, returns errors compatible object on error (an array of strings)
class ValidateParamsType extends BaseType
  test_input_type = types.annotate types.table, format_error: (val, err) => "params: #{err}"
  is_base_type = instance_of BaseType

  validate_type = types.one_of {
    -- instance_of(ValidateParamsType) / (t) ->
    is_base_type
  }

  param_validator_spec = types.annotate types.shape({
    types.string\tag "field"
    validate_type\describe("tableshape type")\tag "type" -- TODO: extract AssertErrorType wrapped type out so we don't yield error when processing entire object

    error: types.nil + types.string\tag "error"
    label: types.nil + types.string\tag "label"
    as: types.nil + types.string\tag "as"
  }), format_error: (val, err) => "validate_params: Invalid validation specification object: #{err}"

  assert_errors: =>
    AssertErrorType @

  new: (params_spec) =>
    @params_spec = for idx, validator in pairs params_spec
      t, err = param_validator_spec validator

      unless t
        error "#{err} (index: #{idx})"

      t

  _transform: (value, state) =>
    pass, err = test_input_type value
    unless pass
      -- NOTE: must always return table of errors, different from tableshape
      return FailedTransform, {err}

    out = {}

    local errors, state

    for validation in *@params_spec
      result, state_or_err = validation.type\_transform value[validation.field], state

      if result == FailedTransform
        errors = {} unless errors

        if validation.error -- override error message
          table.insert errors, validation.error
        else
          error_prefix = "#{validation.label or validation.field}: "

          if type(state_or_err) == "table"
            for e in *state_or_err
              table.insert errors, error_prefix .. e
          else
            table.insert errors, error_prefix .. state_or_err

        -- accumulate error and don't update state
      else
        state = state_or_err
        out[validation.as or validation.field] = result
      
    if errors
      return FailedTransform, errors

    out, state

  _describe: =>

    rows = for thing in *@params_spec
      "#{thing.field}: #{indent tostring thing.type}"

    if #rows == 1
      "params type {#{rows[1]}}"
    else
      "params type {\n  #{table.concat rows, "\n  "}\n}"

{
  validate_params: ValidateParamsType
  assert_error: AssertErrorType
}
