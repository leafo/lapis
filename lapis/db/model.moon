db = require "lapis.db"

import underscore, escape_pattern, uniquify from require "lapis.util"
import insert, concat from table

cjson = require "cjson"

local *

class Model
  @timestamp: false
  @primary_key: "id"
  @schema: "public"

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

  @table_name = =>
    name = underscore @__name
    @table_name = -> name
    name

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
       tbl_name = db.escape_identifier @table_name!
       schema_name = db.escape_identifier @schema
       full_name = tbl_name .. "." .. schema_name
  --   db.delete full_name, query, ...

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
    schema_name = db.escape_identifier @schema

    fields = opts.fields or "*"
    if res = db.select "#{fields} from #{schema_name}.#{tbl_name} #{query}"
      @load_all res

  @count: (clause, ...) =>
    tbl_name = db.escape_identifier @table_name!
    schema_name = db.escape_identifier @schema
    query = "COUNT(*) as c from #{schema_name}.#{tbl_name}"

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
  -- -- Have games, inlcude users
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
    if type(@primary_key) == "table"
      error "model must have singular primary key to include"

    fields = opts and opts.fields or "*"

    flip = opts and opts.flip

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
      schema_name = db.escape_identifier @schema
      find_by_escaped = db.escape_identifier find_by

      query = "#{fields} from #{schema_name}.#{tbl_name} where #{find_by_escaped} in (#{flat_ids})"

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

        for other in *other_records
          other[field_name] = records[other[src_key]]

    other_records

  @find_all: (ids, by_key=@primary_key) =>
    fields = "*"

    -- parse opts
    if type(by_key) == "table"
      fields = by_key.fields or fields
      by_key = by_key.key or @primary_key

    if type(by_key) == "table"
      error "find_all must have a singular key to search"

    return {} if #ids == 0
    flat_ids = concat [db.escape_literal id for id in *ids], ", "
    primary = db.escape_identifier by_key
    tbl_name = db.escape_identifier @table_name!
    schema_name = db.escape_identifier @schema

    if res = db.select fields .. " from #{schema_name}.#{tbl_name} where #{primary} in (#{flat_ids})"
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
    schema_name = db.escape_identifier @schema

    if result = unpack db.select "* from #{schema_name}.#{table_name} where #{cond} limit 1"
      @load result

  -- create from table of values, return loaded object
  @create: (values) =>
    if @constraints
      for key, value in pairs values
        if err = @_check_constraint key, value, values
          return nil, err

    values._timestamp = true if @timestamp
    tbl_name = db.escape_identifier @table_name!
    schema_name = db.escape_identifier @schema
    full_name = tbl_name .. "." .. schema_name
    res = db.insert full_name, values, @primary_keys!
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
    schema_name = db.escape_identifier @schema
    nil != unpack db.select "1 from #{schema}.#{table_name} where #{cond} limit 1"

  @_check_constraint: (key, value, obj) =>
    return unless @constraints
    if fn = @constraints[key]
      fn @, value, key, obj

  @paginated: (...) =>
    Paginator @, ...

  -- alternative to MoonScript inheritance
  @extend: (name, tbl) =>
    lua = require "lapis.lua"
    with cls = lua.class name, tbl, @
      .primary_key = tbl.primary_key
      .timestamp = tbl.timestamp

  _primary_cond: =>
    cond = {}
    for key in *{@@primary_keys!}
      val = @[key]
      val = db.NULL if val == nil

      cond[key] = val

    cond

  url_key: => concat [@[key] for key in *{@@primary_keys!}], "-"

  delete: =>
    tbl_name = db.escape_identifier @@table_name!
    schema_name = db.escape_identifier @schema
    full_name = tbl_name .. "." .. schema_name
    db.delete full_name, @_primary_cond!

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

    values._timestamp = true if @@timestamp
    tbl_name = db.escape_identifier @@table_name!
    schema_name = db.escape_identifier @schema
    full_name = tbl_name .. "." .. schema_name
    db.update full_name, values, cond



class Paginator
  per_page: 10

  new: (@model, clause, ...) =>
    param_count = select "#", ...

    opts = if param_count > 0
      last = select param_count, ...
      type(last) == "table" and last

    @per_page = @model.per_page
    @per_page = opts.per_page if opts
    @prepare_results = opts.prepare_results if opts and opts.prepare_results

    @_clause = db.interpolate_query clause, ...
    @opts = opts

  get_all: =>
    @.prepare_results @model\select @_clause, @opts

  -- 1 indexed page
  get_page: (page) =>
    page = (math.max 1, tonumber(page) or 0) - 1
    @.prepare_results @model\select @_clause .. [[
      limit ?
      offset ?
    ]], @per_page, @per_page * page, @opts

  num_pages: =>
    math.ceil @total_items! / @per_page

  total_items: =>
    @_count or= @model\count db.parse_clause(@_clause).where
    @_count

  prepare_results: (...) -> ...

{ :Model, :Paginator }

