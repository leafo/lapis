local types, BaseType, FailedTransform
do
  local _obj_0 = require("tableshape")
  types, BaseType, FailedTransform = _obj_0.types, _obj_0.BaseType, _obj_0.FailedTransform
end
local instance_of
instance_of = require("tableshape.moonscript").instance_of
local yield_error
yield_error = require("lapis.application").yield_error
local unpack = unpack or table.unpack
local indent
indent = function(str)
  local rows
  do
    local _accum_0 = { }
    local _len_0 = 1
    for s in str:gmatch("[^\n]+") do
      _accum_0[_len_0] = s
      _len_0 = _len_0 + 1
    end
    rows = _accum_0
  end
  return table.concat((function()
    local _accum_0 = { }
    local _len_0 = 1
    for idx, r in ipairs(rows) do
      _accum_0[_len_0] = idx > 1 and "  " .. tostring(r) or r
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), "\n")
end
local AssertErrorType
do
  local _class_0
  local _parent_0 = types.assert
  local _base_0 = {
    assert = function(first, msg, ...)
      if not (first) then
        if type(msg) == "table" then
          coroutine.yield("error", msg)
        else
          yield_error(msg or "unknown error")
        end
        assert(first, msg, ...)
      end
      return first, msg, ...
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "AssertErrorType",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  AssertErrorType = _class_0
end
local ParamsShapeType
do
  local _class_0
  local test_input_type, is_base_type, param_validator_spec
  local _parent_0 = BaseType
  local _base_0 = {
    assert_errors = function(self)
      return AssertErrorType(self)
    end,
    _transform = function(self, value, state)
      local pass, err = test_input_type(value)
      if not (pass) then
        return FailedTransform, {
          tostring(self.error_prefix or "params") .. ": " .. tostring(err)
        }
      end
      local out = { }
      local errors
      local _list_0 = self.params_spec
      for _index_0 = 1, #_list_0 do
        local validation = _list_0[_index_0]
        local result, state_or_err = validation.type:_transform(value[validation.field], state)
        if result == FailedTransform then
          if not (errors) then
            errors = { }
          end
          if validation.error then
            table.insert(errors, validation.error)
          else
            local error_prefix = tostring(validation.label or validation.field) .. ": "
            if self.error_prefix then
              error_prefix = tostring(self.error_prefix) .. ": " .. tostring(error_prefix)
            end
            if type(state_or_err) == "table" then
              for _index_1 = 1, #state_or_err do
                local e = state_or_err[_index_1]
                table.insert(errors, error_prefix .. e)
              end
            else
              table.insert(errors, error_prefix .. state_or_err)
            end
          end
        else
          state = state_or_err
          out[validation.as or validation.field] = result
        end
      end
      if errors then
        return FailedTransform, errors
      end
      return out, state
    end,
    _describe = function(self)
      local rows
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.params_spec
        for _index_0 = 1, #_list_0 do
          local thing = _list_0[_index_0]
          _accum_0[_len_0] = tostring(thing.field) .. ": " .. tostring(indent(tostring(thing.type)))
          _len_0 = _len_0 + 1
        end
        rows = _accum_0
      end
      if #rows == 1 then
        return "params type {" .. tostring(rows[1]) .. "}"
      else
        return "params type {\n  " .. tostring(table.concat(rows, "\n  ")) .. "\n}"
      end
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, params_spec, opts)
      self.error_prefix = opts and opts.error_prefix
      do
        local _accum_0 = { }
        local _len_0 = 1
        for idx, validator in pairs(params_spec) do
          local t, err = param_validator_spec(validator)
          if not (t) then
            error(tostring(err) .. " (index: " .. tostring(idx) .. ")")
          end
          local _value_0 = t
          _accum_0[_len_0] = _value_0
          _len_0 = _len_0 + 1
        end
        self.params_spec = _accum_0
      end
    end,
    __base = _base_0,
    __name = "ParamsShapeType",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  test_input_type = types.table
  is_base_type = instance_of(BaseType)
  param_validator_spec = types.annotate(types.shape({
    types.string:tag("field"),
    is_base_type:describe("tableshape type"):tag("type"),
    error = types["nil"] + types.string:tag("error"),
    label = types["nil"] + types.string:tag("label"),
    as = types["nil"] + types.string:tag("as")
  }), {
    format_error = function(self, val, err)
      return "params_shape: Invalid validation specification object: " .. tostring(err)
    end
  })
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ParamsShapeType = _class_0
end
local MultiParamsType
do
  local _class_0
  local is_params_type
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, value, state)
      local out, errors
      local _list_0 = self.params_shapes
      for _index_0 = 1, #_list_0 do
        local params = _list_0[_index_0]
        local res, new_state = params:_transform(value, state)
        if res == FailedTransform then
          errors = errors or { }
          local _exp_0 = type(new_state)
          if "table" == _exp_0 then
            for _index_1 = 1, #new_state do
              local err = new_state[_index_1]
              table.insert(errors, err)
            end
          elseif "string" == _exp_0 then
            table.insert(errors, new_state)
          end
          if not (types.table(value)) then
            return FailedTransform, errors
          end
        else
          state = new_state
          if out then
            for k, v in pairs(res) do
              out[k] = v
            end
          else
            out = res
          end
        end
      end
      if errors then
        return FailedTransform, errors
      end
      return out, state
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, params_shapes)
      if params_shapes == nil then
        params_shapes = { }
      end
      self.params_shapes = params_shapes
    end,
    __base = _base_0,
    __name = "MultiParamsType",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  is_params_type = instance_of(ParamsShapeType)
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  MultiParamsType = _class_0
end
local printable_character, trim
do
  local _obj_0 = require("lapis.util.utf8")
  printable_character, trim = _obj_0.printable_character, _obj_0.trim
end
local cleaned_text
do
  local Cs, P
  do
    local _obj_0 = require("lpeg")
    Cs, P = _obj_0.Cs, _obj_0.P
  end
  local patt = Cs((printable_character + P(1) / "") ^ 0 * -1)
  cleaned_text = (types.string / function(str)
    return patt:match(str)
  end):describe("text")
end
local valid_text
do
  local patt = printable_character ^ 0 * -1
  valid_text = (types.string * types.custom(function(str)
    return patt:match(str)
  end)):describe("valid text")
end
local trimmed_text = valid_text / (function()
  local _base_0 = trim
  local _fn_0 = _base_0.match
  return function(...)
    return _fn_0(_base_0, ...)
  end
end)() * types.custom(function(v)
  return v ~= "", "expected text"
end):describe("text")
local limited_text
limited_text = function(max_len, min_len)
  if min_len == nil then
    min_len = 1
  end
  local string_length
  string_length = require("lapis.util.utf8").string_length
  local out = trimmed_text * types.custom(function(str)
    local len = string_length(str)
    if not (len) then
      return nil, "invalid text"
    end
    return len <= max_len and len >= min_len
  end)
  return out:describe("text between " .. tostring(min_len) .. " and " .. tostring(max_len) .. " characters")
end
local truncated_text
truncated_text = function(len)
  assert(len, "missing length for shapes.truncated_text")
  return trimmed_text * types.one_of({
    types.string:length(0, len),
    types.string / function(s)
      local C, Cmt
      do
        local _obj_0 = require("lpeg")
        C, Cmt = _obj_0.C, _obj_0.Cmt
      end
      local count = 0
      local pattern = C(Cmt(printable_character, function()
        count = count + 1
        return count <= len
      end) ^ 0)
      return pattern:match(s)
    end
  }) * trimmed_text
end
local db_id = (types.one_of({
  types.number * types.custom(function(v)
    return v == math.floor(v)
  end),
  types.string:length(1, 11) * trimmed_text * types.pattern("^%d+$") / tonumber
}) * types.range(0, 2147483647)):describe("database ID integer")
local db_enum
db_enum = function(e)
  assert(e, "missing enum for shapes.db_enum")
  local for_db
  do
    local _base_0 = e
    local _fn_0 = _base_0.for_db
    for_db = function(...)
      return _fn_0(_base_0, ...)
    end
  end
  local names = {
    unpack(e)
  }
  return types.one_of({
    types.one_of(names) / for_db,
    db_id / tonumber * types.custom(function(n)
      return e[n]
    end) / for_db
  }):describe("enum(" .. tostring(table.concat(names, ", ")) .. ")")
end
local empty = types.one_of({
  types["nil"],
  types.pattern("^%s*$") / nil
}):describe("empty")
local file_upload = types.partial({
  filename = types.string * -empty,
  content = -types.literal("")
}):describe("file upload")
return setmetatable({
  params_shape = ParamsShapeType,
  multi_params = MultiParamsType,
  assert_error = AssertErrorType,
  cleaned_text = cleaned_text,
  valid_text = valid_text,
  trimmed_text = trimmed_text,
  truncated_text = truncated_text,
  limited_text = limited_text,
  empty = empty,
  file_upload = file_upload,
  db_id = db_id,
  db_enum = db_enum
}, {
  __index = types
})
