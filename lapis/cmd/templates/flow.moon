
check_args = (name, more) ->
  error "flow template takes arguments: name" unless name

  if name\match "%u"
    error "name should be underscore form, all lowercase"

  if more
    error "got a second argument to generator, did you mean to pass a string?"

filename = (name) ->
  "flows/#{name}.moon"

content = (name) ->
  [[import Flow from require "lapis.flow"

class ]].. name .. [[ extends Flow
  ]]

write = (writer, name) ->
  import camelize from require "lapis.util"
  tail_name = name\match("[^.]+$") or name
  class_name = camelize(tail_name) .. "Flow"

  path = writer\mod_to_path name
  writer\write filename(path), content class_name

{:check_args, :write}


