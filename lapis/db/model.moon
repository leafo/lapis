
db = require "lapis.db"

import underscore from require "lapis.util"

class Model
  @timestamp: false
  @primary_key: "id"

  @primary_keys: =>
    if type(@primary_key) == "table"
      unpack @primary_key
    else
      @primary_key

  @encode_key = (...) =>
    if type(@primary_key) == "table"
      { k, select i, ... for i, k in ipairs @primary_key }
    else
      { [@primary_key]: ... }

  @table_name = => underscore @__name

  @load: (tbl) =>
    setmetatable tbl, @__base

  -- find by primary key, or by table of conds
  @find: (...) =>
    cond = if "table" == type select 1, ...
      db.encode_assigns (...), nil, "and"
    else
      db.encode_assigns @encode_key(...), nil, "and"

    table_name = db.escape_identifier @table_name!

    if result = unpack db.select "* from #{table_name} where #{cond} limit 1"
      @load result

  -- create from table of values, return loaded object
  @create: (values) =>
    values._timestamp = true if @timestamp
    res = db.insert @table_name!, values, @primary_keys!
    if res
      if res.resultset
        for k,v in pairs res.resultset[1]
          values[k] = v
      @load values

  @check_unique_constraint: (name, value) =>
    cond = db.encode_assigns { [name]: value }
    table_name = db.escape_identifier @table_name!
    res = unpack db.select "COUNT(*) as c from #{table_name} where #{cond}"
    res.c > 0

{ :Model }

