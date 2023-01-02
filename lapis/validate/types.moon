
import types, BaseType, FailedTransform from require "tableshape"

import assert_error from require "lapis.application"

-- like assert but it uses assert_error to throw the error
-- note: in newer version of tableshape we cna use override the assert
-- property on the class instead of overriding method
class AssertErrorType extends types.assert
  assert: assert_error

-- type that can validate params object, returning only the fields that are specified
-- this is different than types.shape because it:
-- * takes a ordered list of field names that can apply customizations
-- * aggregates all errors into a table, returns errors compatible object on error (an array of strings)
class ParamsType extends BaseType
  test_input_type = types.annotate(types.table, format_error: (val, err) => "params: #{err}")

  new: (@params_spec, @opts) =>

  _transform: (value, state) =>
    pass, err = test_input_type value
    unless pass
      return FailedTransform, err

    local errors, state

    for validation in *@params_spec
      nil

  _describe: =>
    "params validator"

{
  params: ParamsType
  assert_error: AssertErrorType
}
