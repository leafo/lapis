
db = require "lapis.db"

import underscore, escape_pattern, uniquify from require "lapis.util"
import insert, concat from table

cjson = require "cjson"
import OffsetPaginator from require "lapis.db.pagination"

local *

class Model
  @timestamp: false
  @primary_key: "id"

  @primary_keys: =>
    if type(@primary_key) == "table"
      unpack @primary_key
    else
      @primary_key

  @encode_key: (...) =>
    if type(@primary_key) == "table"
      { k, select i, ... for i, k in ipairs @primary_key }
    else
      { [@primary_key]: ... }

  @table_name: =>
    name = underscore @__name
    @table_name = -> name
    name

  @columns: =>
    columns = db.query [[
      select column_name, data_type
      from information_schema.columns
      where table_name = ?]], @table_name!

    @columns = -> columns
    columns

  @load: (tbl) =>
    for k,v in pairs tbl
      -- clear null values
      if ngx and v == ngx.null or v == cjson.null
        tbl[k] = nil

    setmetatable tbl, @__base

  @load_all: (tbls) =>
    [@load t for t in *tbls]

  -- @delete: (query, ...) =>
  --   assert query, "tried to delete with no query"
  --   db.delete @table_name!, query, ...

  @select: (query="", ...) =>
    opts = {}
    param_count = select "#", ...

    if param_count > 0
      last = select param_count, ...
      opts = last if type(last) == "table"

    if type(query) == "table"
      opts = query
      query = ""

    query = db.interpolate_query query, ...
    tbl_name = db.escape_identifier @table_name!

    fields = opts.fields or "*"
    if res = db.select "#{fields} from #{tbl_name} #{query}"
      @load_all res

  @count: (clause, ...) =>
    tbl_name = db.escape_identifier @table_name!
    query = "COUNT(*) as c from #{tbl_name}"

    if clause
      query ..= " where " .. db.interpolate_query clause, ...

    unpack(db.select query).c

  -- include references to this model in a list of records based on a foreign
  -- key
  -- Examples:
  --
  -- -- Models
  -- Users { id, name }
  -- Games { id, user_id, title }
  --
  -- -- Have games, include users
  -- games = Games\select!
  -- Users\include_in games, "user_id"
  --
  -- -- Have users, get games (be careful of many to one, only one will be
  -- -- assigned but all will be fetched)
  -- users = Users\select!
  -- Games\include_in users, "user_id", flip: true
  --
  -- specify as: "name" to set the key of the included objects in each item
  -- from the source list
  @include_in: (other_records, foreign_key, opts) =>
    fields = opts and opts.fields or "*"
    flip = opts and opts.flip

    if not flip and type(@primary_key) == "table"
      error "model must have singular primary key to include"

    src_key = flip and "id" or foreign_key
    include_ids = for record in *other_records
      with id = record[src_key]
        continue unless id

    if next include_ids
      include_ids = uniquify include_ids
      flat_ids = concat [db.escape_literal id for id in *include_ids], ", "

      find_by = if flip
        foreign_key
      else
        @primary_key

      tbl_name = db.escape_identifier @table_name!
      find_by_escaped = db.escape_identifier find_by

      query = "#{fields} from #{tbl_name} where #{find_by_escaped} in (#{flat_ids})"

      if opts and opts.where
        query ..= " and " .. db.encode_clause opts.where

      if res = db.select query
        records = {}
        for t in *res
          records[t[find_by]] = @load t

        field_name = if opts and opts.as
          opts.as
        elseif flip
          -- TODO: need a proper singularize
          tbl = @table_name!
          tbl\match"^(.*)s$" or tbl
        else
          foreign_key\match "^(.*)_#{escape_pattern(@primary_key)}$"

        assert field_name, "failed to infer field name, provide one with `as`"

        for other in *other_records
          other[field_name] = records[other[src_key]]

    other_records
    
  @select_all: (conditions) =>
    fields = ""
    query = ""
    where = conditions.where
    group_by = conditions.group_by
    order_by = conditions.order_by

    flat_group_by = concat [db.escape_literal cond for cond in *group_by], ", "
    if where
      where_query = ""
      where_count = 0
      if where.in
        for key, tbl_value in pairs where.in
          values = concat [db.escape_literal value for value in *tbl_value], ", "
          if values ~= "" then 
            if where_count > 0 then where_query ..= " AND"
            where_query ..= " #{key} in (#{values})"
            where_count += 1
      if where.range
        condition = ""
        is_second = false
        for key, tbl_value in pairs where.range
            if where_count > 0 then condition ..= " AND "
            condition ..= "("
            for i in *tbl_value do
              if i.begin and i.end
                if is_second
                  condition ..= " OR "
                is_second = true
                condition ..= "#{db.escape_identifier key} BETWEEN " .. db.escape_literal(i.begin) .. " AND " .. db.escape_literal(i.end)
            condition ..= ")"
            is_second = false
        where_query ..= condition
      if where_query ~= "" then where_query = " WHERE" .. where_query
      query ..= where_query
    if group_by
      values = concat [db.escape_identifier value for value in *group_by], ", "
      query ..= " GROUP BY #{values}"
    if conditions.order_by
      values = concat [db.escape_identifier(column) .. " " .. order for column, order in pairs(conditions.order_by)], ", "
      query ..= " ORDER BY #{values}"
    if conditions.limit
      query ..= " LIMIT " .. tonumber conditions.limit
    if conditions.offset
      query ..= " OFFSET " .. tonumber conditions.offset
    if conditions.fields
      for func, field in pairs conditions.fields
        if fields ~= "" then fields ..= ", "
        fields ..= switch func
          when "single"
            concat [db.escape_identifier value for value in *field], ", "
          when "text"
            field
          else
            concat ["#{func}(" .. db.escape_identifier(value) .. ") as " .. db.escape_identifier(value) for value in *field], ", "
    tbl_name = db.escape_identifier @table_name!
    query = fields .. " FROM #{tbl_name}" .. query
    if res = db.select query
      @load r for r in *res
      res
  
  @find_all: (ids, by_key=@primary_key) =>
    where = nil
    fields = "*"

    -- parse opts
    if type(by_key) == "table"
      fields = by_key.fields or fields
      where = by_key.where
      by_key = by_key.key or @primary_key

    if type(by_key) == "table" and by_key[1] != "raw"
      error "find_all must have a singular key to search"

    return {} if #ids == 0
    flat_ids = concat [db.escape_literal id for id in *ids], ", "
    primary = db.escape_identifier by_key
    tbl_name = db.escape_identifier @table_name!

    query = fields .. " from #{tbl_name} where #{primary} in (#{flat_ids})"

    if where
      query ..= " and " .. db.encode_clause where

    if res = db.select query
      @load r for r in *res
      res

  -- find by primary key, or by table of conds
  @find: (...) =>
    first = select 1, ...
    error "(#{@table_name!}) trying to find with no conditions" if first == nil

    cond = if "table" == type first
      db.encode_clause (...)
    else
      db.encode_clause @encode_key(...)

    table_name = db.escape_identifier @table_name!

    if result = unpack db.select "* from #{table_name} where #{cond} limit 1"
      @load result

  -- create from table of values, return loaded object
  @create: (values) =>
    if @constraints
      for key in pairs @constraints
        if err = @_check_constraint key, values and values[key], values
          return nil, err

    values._timestamp = true if @timestamp
    res = db.insert @table_name!, values, @primary_keys!
    if res
      for k,v in pairs res[1]
        values[k] = v
      @load values
    else
      nil, "Failed to create #{@__name}"

  -- returns true if something is using the cond
  @check_unique_constraint: (name, value) =>
    t = if type(name) == "table"
      name
    else
      { [name]: value }

    cond = db.encode_clause t
    table_name = db.escape_identifier @table_name!
    nil != unpack db.select "1 from #{table_name} where #{cond} limit 1"

  @_check_constraint: (key, value, obj) =>
    return unless @constraints
    if fn = @constraints[key]
      fn @, value, key, obj

  @paginated: (...) =>
    OffsetPaginator @, ...

  -- alternative to MoonScript inheritance
  @extend: (table_name, tbl={}) =>
    lua = require "lapis.lua"
    with cls = lua.class table_name, tbl, @
      .table_name = -> table_name
      .primary_key = tbl.primary_key
      .timestamp = tbl.timestamp
      .constraints = tbl.constraints

  _primary_cond: =>
    cond = {}
    for key in *{@@primary_keys!}
      val = @[key]
      val = db.NULL if val == nil

      cond[key] = val

    cond

  url_key: => concat [@[key] for key in *{@@primary_keys!}], "-"

  delete: =>
    db.delete @@table_name!, @_primary_cond!

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

    return if next(columns) == nil
    values = { col, @[col] for col in *columns }

    if @@constraints
      for key, value in pairs values
        if err = @@_check_constraint key, value, @
          return nil, err

    -- update options
    nargs = select "#", ...
    last = nargs > 0 and select nargs, ...

    opts = if type(last) == "table" then last

    if @@timestamp and not (opts and opts.timestamp == false)
      values._timestamp = true

    db.update @@table_name!, values, cond

  -- reload fields on the instance
  refresh: (fields="*", ...) =>
    local field_names

    if fields != "*"
      field_names = {fields, ...}
      fields = table.concat [db.escape_identifier f for f in *field_names], ", "

    cond = db.encode_clause @_primary_cond!
    tbl_name = db.escape_identifier @@table_name!
    res = unpack db.select "#{fields} from #{tbl_name} where #{cond}"

    if field_names
      for field in *field_names
        @[field] = res[field]
    else
      for k,v in pairs @
        @[k] = nil

      for k,v in pairs res
        @[k] = v

      @@load @

    @

{ :Model }

