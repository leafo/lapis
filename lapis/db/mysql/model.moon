db = require "lapis.db.mysql"

import BaseModel, Enum, enum from require "lapis.db.base_model"
import preload from require "lapis.db.model.relations"

class Model extends BaseModel
  @db: db

  @columns: =>
    columns = @db.query "
      SHOW COLUMNS FROM #{@db.escape_identifier @table_name!}
    "
    columns = [c for c in *columns] -- strip extra data from query
    @columns = -> columns
    columns

  -- create from table of values, return loaded object
  @create: (values, opts) =>
    if @constraints
      for key in pairs @constraints
        if err = @_check_constraint key, values and values[key], values
          return nil, err

    if @timestamp
      time = @db.format_date!
      values.created_at or= time
      values.updated_at or= time

    res = db.insert @table_name!, values

    if res
      -- NOTE: Due to limitation of mysql bindings, we don't know how to set
      -- the autoincrementing id to the correct column name on composite keys.
      -- Developer will have to manually read the id out and assign it
      -- Recommendation: use mariadb which supports RETURNING syntax
      new_id = res.last_auto_id or res.insert_id
      if not values[@primary_key] and new_id and new_id != 0
        values[@primary_key] = new_id
      @load values
    else
      nil, "Failed to create #{@__name}"

  @find_all: (...) =>
    res = BaseModel.find_all @, ...
    if res[1]
      -- strip out extra data from query
      [r for r in *res]
    else
      res

  -- thing\update "col1", "col2", "col3"
  -- thing\update {
  --   "col1", "col2"
  --   col3: "Hello"
  -- }
  update: (first, ...) =>
    cond = @_primary_cond!

    columns = if type(first) == "table"
      for k,v in pairs first
        if type(k) == "number"
          v
        else
          @[k] = v
          k
    else
      {first, ...}

    return nil, "nothing to update" if next(columns) == nil

    if @@constraints
      for _, column in pairs columns
        if err = @@_check_constraint column, @[column], @
          return nil, err

    values = { col, @[col] for col in *columns }

    -- update options
    nargs = select "#", ...
    last = nargs > 0 and select nargs, ...

    opts = if type(last) == "table" then last

    if @@timestamp and not (opts and opts.timestamp == false)
      time = @@db.format_date!
      values.updated_at or= time

    res = db.update @@table_name!, values, cond
    (res.affected_rows or 0) > 0, res

{ :Model, :Enum, :enum, :preload }
