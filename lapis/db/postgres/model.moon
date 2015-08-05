db = require "lapis.db.postgres"

import BaseModel, Enum, enum from require "lapis.db.base_model"

class Model extends BaseModel
  @db: db

  -- create from table of values, return loaded object
  @create: (values, opts) =>
    if @constraints
      for key in pairs @constraints
        if err = @_check_constraint key, values and values[key], values
          return nil, err

    values._timestamp = true if @timestamp

    local returning

    if opts and opts.returning
      returning = { @primary_keys! }
      for field in *opts.returning
        table.insert returning, field

    for k, v in pairs values
      if db.is_raw v
        returning or= {@primary_keys!}
        table.insert returning, k

    res = if returning
      db.insert @table_name!, values, unpack returning
    else
      db.insert @table_name!, values, @primary_keys!

    if res
      if returning
        for k in *returning
          values[k] = res[1][k]

      for k,v in pairs res[1]
        values[k] = v

      @load values
    else
      nil, "Failed to create #{@__name}"

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
      values._timestamp = true

    local returning
    for k, v in pairs values
      if db.is_raw v
        returning or= {}
        table.insert returning, k

    if returning
      with res = db.update @@table_name!, values, cond, unpack returning
        if update = unpack res
          for k in *returning
            @[k] = update[k]
    else
      db.update @@table_name!, values, cond

{ :Model, :Enum, :enum }
