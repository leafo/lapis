
check_args = (name, more) ->
  error "model template takes arguments: name" unless name

  if name\match "%u"
    error "name should be underscore form, all lowercase"

  if more
    error "got a second argument to generator, did you mean to pass a string?"

filename = (name) ->
  "models/#{name}.moon"

write = (writer, name) ->
  import camelize from require "lapis.util"
  class_name = camelize name

  writer\write filename(name), [[db = require "lapis.db"
import Model from require "lapis.db.model"

class ]] .. class_name .. [[ extends Model
]]

{:check_args, :write}

