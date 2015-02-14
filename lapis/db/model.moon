
db = require "lapis.db"

import underscore, escape_pattern, uniquify, get_fields from require "lapis.util"
import insert, concat from table

cjson = require "cjson"
import OffsetPaginator from require "lapis.db.pagination"

local *

-- TODO: need a proper singularize
singularize = (name)->
  name\match"^(.*)s$" or name

class Enum
  -- convert string to number, or let number pass through
  for_db: (key) =>
    if type(key) == "string"
      (assert @[key], "enum does not contain key #{key}")
    elseif type(key) == "number"
      assert @[key], "enum does not contain val #{key}"
      key
    else
      error "don't know how to handle type #{type key} for enum"

  -- convert number to string, or let string pass through
  to_name: (val) =>
    if type(val) == "string"
      assert @[val], "enum does not contain key #{val}"
      val
    elseif type(val) == "number"
      key = @[val]
      (assert key, "enum does not contain val #{val}")
    else
      error "don't know how to handle type #{type val} for enum"

enum = (tbl) ->
  keys = [k for k in pairs tbl]
  for key in *keys
    tbl[tbl[key]] = key

  setmetatable tbl, Enum.__base

-- class Things extends Model
--   @relations: {
--     {"user", has_one: "Users"}
--     {"posts", has_many: "Posts", pager: true, order: "id ASC"}
--   }
add_relations = (relations) =>
  for relation in *relations
    name = assert relation[1], "missing relation name"
    fn_name = relation.as or "get_#{name}"
    assert_model = (source) ->
      models = require "models"
      with m = models[source]
        error "failed to find model `#{source}` for relationship" unless m

    if source = relation.fetch
      assert type(source) == "function", "Expecting function for `fetch` relation"
      @__base[fn_name] = =>
        existing = @[name]
        return existing if existing != nil
        with obj = source @
          @[name] = obj

    if source = relation.has_one
      assert type(source) == "string", "Expecting model name for `has_one` relation"
      @__base[fn_name] = =>
        existing = @[name]
        return existing if existing != nil
        model = assert_model source

        clause = {
          [relation.key or "#{singularize @@table_name!}_id"]: @[@@primary_keys!]
        }

        with obj = model\find clause
          @[name] = obj


    if source = relation.belongs_to
      assert type(source) == "string", "Expecting model name for `belongs_to` relation"
      column_name = "#{name}_id"

      @__base[fn_name] = =>
        return nil unless @[column_name]
        existing = @[name]
        return existing if existing != nil
        model = assert_model source
        with obj = model\find @[column_name]
          @[name] = obj

    if source = relation.has_many
      if relation.pager != false
        foreign_key = relation.key
        @__base[fn_name] = (opts) =>
          model = assert_model source
          clause = {
            [foreign_key or "#{singularize @@table_name!}_id"]: @[@@primary_keys!]
          }

          if where = relation.where
            for k,v in pairs where
              clause[k] = v

          clause = db.encode_clause clause

          model\paginated "where #{clause}", opts
      else
        error "not yet"

class Model
  @timestamp: false
  @primary_key: "id"

  @__inherited: (child) =>
    if r = child.relations
      add_relations child, r

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
          singularize @table_name!
        else
          foreign_key\match "^(.*)_#{escape_pattern(@primary_key)}$"

        assert field_name, "failed to infer field name, provide one with `as`"

        for other in *other_records
          other[field_name] = records[other[src_key]]

    other_records

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

    error "missing constraint to check" unless next t

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
    res =  db.delete @@table_name!, @_primary_cond!
    res.affected_rows and res.affected_rows > 0, res

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
          for k, v in pairs update
            @[k] = v
    else
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

    unless res
      error "failed to find row to refresh from, did the primary key change?"

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

{ :Model, :Enum, :enum }

