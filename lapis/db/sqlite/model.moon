db = require "lapis.db.sqlite"

import BaseModel, Enum, enum from require "lapis.db.base_model"
import preload from require "lapis.db.model.relations"

class Model extends BaseModel
  @db: db

  @columns: =>
    columns = @db.query "PRAGMA table_info(?)", @table_name!
    @columns = -> columns
    columns

{ :Model, :Enum, :enum, :preload }
