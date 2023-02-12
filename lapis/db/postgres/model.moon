db = require "lapis.db.postgres"

import select, pairs, type, select from _G
unpack = unpack or table.unpack
import insert from table

import BaseModel, Enum, enum from require "lapis.db.base_model"
import preload from require "lapis.db.model.relations"

class Model extends BaseModel
  @db: db

  @columns: =>
    columns = @db.query [[SELECT column_name, data_type FROM information_schema.columns WHERE table_name = ?]], @table_name!

    @columns = -> columns
    columns


{ :Model, :Enum, :enum, :preload }
