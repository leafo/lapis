
check_args = (name) ->
  error "model template takes arguments: name" unless name

content = (name) ->
  import camelize from require "lapis.util"
  class_name = camelize name

  [[db = require "lapis.db"
import Model from require "lapis.db.model"

class ]] .. class_name .. [[ extends Model
]]

filename = (name) ->
  "models/#{name}.moon"

{:content, :filename, :check_args}

