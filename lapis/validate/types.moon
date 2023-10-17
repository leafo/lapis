
import types, BaseType, FailedTransform from require "tableshape"
import instance_of from require "tableshape.moonscript"

import yield_error from require "lapis.application"

coroutine = require "lapis.coroutine"

unpack = unpack or table.unpack

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
class ParamsShapeType extends BaseType
  test_input_type = types.table
  is_base_type = instance_of BaseType

  param_validator_spec = types.annotate types.shape({
    (types.string + types.number)\tag "field"

     -- TODO: AssertErrorType should be unwrapped so we don't yield error when processing nested object
    is_base_type\describe("tableshape type")\tag "type"

    error: types.nil + types.string\tag "error"
    label: types.nil + types.string\tag "label"
    as: types.nil + types.string\tag "as"
  }), format_error: (val, err) => "params_shape: Invalid validation specification object: #{err}"

  assert_errors: =>
    AssertErrorType @

  new: (params_spec, opts) =>
    @error_prefix = opts and opts.error_prefix
    @params_spec = for idx, validator in pairs params_spec
      t, err = param_validator_spec validator

      unless t
        error "#{err} (index: #{idx})"

      t

  _transform: (value, state) =>
    pass, err = test_input_type value
    unless pass
      -- NOTE: must always return table of errors, different from tableshape
      return FailedTransform, {"#{@error_prefix or "params"}: #{err}"}

    -- NOTE: it's important that out always return a fresh object,
    -- and that it doesn't pass through the object even if it
    -- perfectly matches the spec. This is well defined in the API
    out = {}

    local errors

    for validation in *@params_spec
      result, state_or_err = validation.type\_transform value[validation.field], state

      if result == FailedTransform
        errors = {} unless errors

        if validation.error -- override error message
          table.insert errors, validation.error
        else
          error_prefix = "#{validation.label or validation.field}: "
          if @error_prefix
            error_prefix = "#{@error_prefix}: #{error_prefix}"

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


-- tests every key, value pair in the table
-- types.params_map(types.db_id, types.params_shape {...})
class ParamsMapType extends BaseType
  @ordered_pairs: (obj) ->
    coroutine.wrap ->
      keys = {}
      for k in pairs obj
        table.insert keys, k

      table.sort keys

      for k in *keys
        coroutine.yield k, obj[k]

  test_input_type = types.table

  iter: pairs
  item_prefix: "item"

  new: (@key_type, @value_type, opts) =>
    if opts
      @item_prefix = opts.item_prefix
      @iter = opts.iter
      @join_error = opts.join_error

  join_error: (err, key, value, error_type) =>
    switch error_type
      when "key"
        "#{@item_prefix} key: #{err}"
      else
        "#{@item_prefix} #{key}: #{err}"

  _transform: (input_value, state) =>
    pass, err = test_input_type input_value
    unless pass
      return FailedTransform, {"params map: #{err}"}

    local errors

    push_error = (err, ...) ->
      errors or= {}

      switch type(err)
        -- append all errors
        when "table"
          for e in *err
            table.insert errors, @join_error e, ...
        when "string"
          table.insert errors, @join_error err, ...

    out = {}

    for key, value in @.iter input_value
      pair_state = state

      -- test if key validates
      new_key, state_or_err = @key_type\_transform key, pair_state
      if new_key == FailedTransform
        push_error state_or_err, key, value, "key"
        -- Note that if the key fails, we bypass the value test
        continue
      else
        pair_state = state_or_err

      -- test if value validates
      new_value, state_or_err = @value_type\_transform value, pair_state
      if new_value == FailedTransform
        push_error state_or_err, key, value, "value"
        continue
      else
        pair_state = state_or_err

      if new_key != nil and new_value != nil
        out[new_key] = new_value

      state = pair_state

    if errors
      return FailedTransform, errors

    out, state

-- applies a params_shape to each item of array. This is necessary because
-- params_shape returns a special errors object
class ParamsArrayType extends BaseType
  test_input_type = types.table

  iter: ipairs
  item_prefix: "item"

  new: (@item_shape, opts) =>
    if opts
      @item_prefix = opts.item_prefix
      @iter = opts.iter
      @join_error = opts.join_error
      @length_type = opts.length

  join_error: (err, idx, item) =>
    "#{@item_prefix} #{idx}: #{err}"

  _transform: (value, state) =>
    pass, err = test_input_type value
    unless pass
      return FailedTransform, {"params array: #{err}"}

    if @length_type
      len = #value
      res, state = @length_type\_transform len, state
      if res == FailedTransform
        return FailedTransform, {"length expected #{@length_type}"}

    local errors

    out = for idx, item in @.iter value
      result, state_or_err = @item_shape\_transform item, state

      if result == FailedTransform
        errors = {} unless errors

        switch type(state_or_err)
          -- append all errors
          when "table"
            for err in *state_or_err
              table.insert errors, @join_error err, idx, item
          when "string"
            table.insert errors, @join_error state_or_err, idx, item
        continue
      else
        state = state_or_err
        result

    if errors
      return FailedTransform, errors

    out, state

-- convert the array-like error message to a single string error messag
class FlattenErrors extends BaseType
  new: (@type) =>

  _transform: (value, state) =>
    value, state_or_err = @type\_transform value, state

    if value == FailedTransform
      switch type(state_or_err)
        -- append all errors
        when "table"
          return FailedTransform, table.concat state_or_err, ", "
        when "string"
          FailedTransform, state_or_err

    value, state_or_err

-- Combines multiple params_shapes into a single result. Each params object is
-- tested in order, and the entire result set is joined into a final object.
-- All of them must pass. the joint error message is returned. receives an
-- array of params types
-- eg.
-- s = types.multi_params {
--   types.params_shape { id: types.int }
--   types.params_shape { name: types.string }
-- }
class MultiParamsType extends BaseType
  new: (@params_shapes={}) =>

  _transform: (value, state) =>
    local out, errors

    for params in *@params_shapes
      res, new_state = params\_transform value, state

      if res == FailedTransform
        errors or= {}

        switch type(new_state)
          -- append all errors
          when "table"
            for err in *new_state
              table.insert errors, err
          when "string"
            table.insert errors, new_state

        -- we terminate early if the input value is the wrong type
        unless types.table value
          return FailedTransform, errors
      else
        state = new_state
        -- we should only merge res if we are sure it came from a safe object for output ?

        if out
          for k,v in pairs res
            out[k] = v
        else
          out = res

    if errors
      return FailedTransform, errors

    out, state

import printable_character, trim from require "lapis.util.utf8"

-- strips invalid unicode sequences
cleaned_text = do
  import Cs, P from require "lpeg"
  patt = Cs (printable_character + P(1) / "")^0 * -1
  (types.string / (str) -> patt\match str)\describe "text"

-- verify string is all valid UTF8
valid_text = do
  patt = printable_character^0 * -1
  (types.string * types.custom((str) -> patt\match str))\describe "valid text"

trimmed_text = valid_text / trim\match * types.custom(
  (v) -> v != "", "expected text"
)\describe "text"

limited_text = (max_len, min_len=1) ->
  import string_length from require "lapis.util.utf8"
  out = trimmed_text * types.custom (str) ->
    len = string_length(str)
    return nil, "invalid text" unless len
    len <= max_len and len >= min_len

  out\describe "text between #{min_len} and #{max_len} characters"

truncated_text = (len) ->
  assert len, "missing length for types.truncated_text"

  trimmed_text * types.one_of({
    types.string\length 0, len
    types.string / (s) ->
      import C, Cmt from require "lpeg"

      count = 0
      pattern = C Cmt(printable_character, ->
        count += 1
        count <= len
      )^0

      pattern\match s
  }) * trimmed_text

-- this represents default 4 byte serial in postgres: https://www.postgresql.org/docs/current/datatype-numeric.html
db_id = (types.one_of({
  types.number * types.custom (v) -> v == math.floor(v)
  types.string\length(1,11) * trimmed_text * types.pattern("^%d+$") / tonumber
}) * types.range(0, 2147483647))\describe "database ID integer"

db_enum = (e) ->
  assert e, "missing enum for types.db_enum"
  for_db = e\for_db

  names = { unpack e }

  types.one_of({
    types.one_of(names) / for_db
    db_id / tonumber * types.custom((n) -> e[n]) / for_db
  })\describe "enum(#{table.concat names, ", "})"

empty = types.one_of({
  types.nil
  types.pattern("^%s*$") / nil
})\describe "empty"

-- NOTE: this is based off of the legacy `lapis.validate` check, it probably
-- needs to be revamped
file_upload = types.partial({
  filename: types.string * -empty
  content: -types.literal("")
})\describe "file upload"


setmetatable {
  params_shape: ParamsShapeType
  params_array: ParamsArrayType
  params_map: ParamsMapType
  flatten_errors: FlattenErrors

  multi_params: MultiParamsType
  assert_error: AssertErrorType

  :cleaned_text
  :valid_text
  :trimmed_text
  :truncated_text
  :limited_text
  :empty
  :file_upload

  :db_id
  :db_enum
}, __index: types
