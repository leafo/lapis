import underscore, escape_pattern, uniquify, singularize from require "lapis.util"
import insert, concat from table

import require, type, setmetatable, rawget, assert, pairs, unpack, error, next from _G

cjson = require "cjson"

import OffsetPaginator from require "lapis.db.pagination"
import add_relations, mark_loaded_relations from require "lapis.db.model.relations"

class Enum
  debug = =>
    "(contains: #{table.concat ["#{i}:#{v}" for i, v in ipairs @], ", "})"

  -- convert string to number, or let number pass through
  for_db: (key) =>
    if type(key) == "string"
      (assert @[key], "enum does not contain key #{key} #{debug @}")
    elseif type(key) == "number"
      assert @[key], "enum does not contain val #{key} #{debug @}"
      key
    else
      error "don't know how to handle type #{type key} for enum"

  -- convert number to string, or let string pass through
  to_name: (val) =>
    if type(val) == "string"
      assert @[val], "enum does not contain key #{val} #{debug @}"
      val
    elseif type(val) == "number"
      key = @[val]
      (assert key, "enum does not contain val #{val} #{debug @}")
    else
      error "don't know how to handle type #{type val} for enum"

enum = (tbl) ->
  keys = [k for k in pairs tbl]
  for key in *keys
    tbl[tbl[key]] = key

  setmetatable tbl, Enum.__base

class BaseModel
  @db: nil -- set in implementing class

  @timestamp: false
  @primary_key: "id"

  @__inherited: (child) =>
    if r = rawget child, "relations"
      add_relations child, r, @db

  @get_relation_model: (name) =>
    require("models")[name]

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
    unless rawget @, "__table_name"
      @__table_name = underscore @__name

    @__table_name

  @scoped_model: (base_model, prefix, mod, external_models) ->
    class extends base_model
      @get_relation_model: if mod
        (name) =>
          if external_models and external_models[name]
            base_model\get_relation_model name
          else
            require(mod)[name]

      @table_name: =>
        "#{prefix}#{base_model.table_name(@)}"

      @singular_name: =>
        singularize base_model.table_name @

  -- used as the forign key name when preloading objects over a relation
  -- user_posts -> user_post
  @singular_name: =>
    singularize @table_name!

  @columns: =>
    columns = @db.query [[
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
  --   @db.delete @table_name!, query, ...

  @select: (query="", ...) =>
    local opts
    param_count = select "#", ...

    if param_count > 0
      last = select param_count, ...
      opts = last if type(last) == "table"

    if type(query) == "table"
      opts = query
      query = ""

    query = @db.interpolate_query query, ...
    tbl_name = @db.escape_identifier @table_name!

    load_as = opts and opts.load
    fields = opts and opts.fields or "*"
    if res = @db.select "#{fields} from #{tbl_name} #{query}"
      return res if load_as == false
      if load_as
        load_as\load_all res
      else
        @load_all res

  @count: (clause, ...) =>
    tbl_name = @db.escape_identifier @table_name!
    query = "COUNT(*) as c from #{tbl_name}"

    if clause
      query ..= " where " .. @db.interpolate_query clause, ...

    unpack(@db.select query).c


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
    many = opts and opts.many
    value_fn = opts and opts.value

    if not flip and type(@primary_key) == "table"
      error "#{@table_name!} must have singular primary key for include_in"

    src_key = flip and (opts.local_key or "id") or foreign_key
    include_ids = for record in *other_records
      with id = record[src_key]
        continue unless id

    if next include_ids
      include_ids = uniquify include_ids
      flat_ids = concat [@db.escape_literal id for id in *include_ids], ", "

      find_by = if flip
        foreign_key
      else
        @primary_key

      tbl_name = @db.escape_identifier @table_name!
      find_by_escaped = @db.escape_identifier find_by

      query = "#{fields} from #{tbl_name} where #{find_by_escaped} in (#{flat_ids})"

      if opts and opts.where
        query ..= " and " .. @db.encode_clause opts.where

      if order = many and opts.order
        query ..= " order by #{order}"

      if group = opts and opts.group
        query ..= " group by #{group}"

      if res = @db.select query
        records = {}
        if many
          for t in *res
            t_key = t[find_by]

            if records[t_key] == nil
              records[t_key] = {}

            row = @load t
            row = value_fn row if value_fn

            insert records[t_key], row
        else
          for t in *res
            row = @load t
            row = value_fn row if value_fn

            records[t[find_by]] = row

        field_name = if opts and opts.as
          opts.as
        elseif flip
          if many
            @table_name!
          else
            @singular_name!
        else
          foreign_key\match "^(.*)_#{escape_pattern(@primary_key)}$"

        assert field_name, "failed to infer field name, provide one with `as`"

        for other in *other_records
          other[field_name] = records[other[src_key]]

          if many and not other[field_name]
            other[field_name] = {}

        if for_relation = opts and opts.for_relation
          mark_loaded_relations other_records, for_relation

    other_records

  @find_all: (ids, by_key=@primary_key) =>
    where = nil
    clause = nil
    fields = "*"

    -- parse opts
    if type(by_key) == "table"
      fields = by_key.fields or fields
      where = by_key.where
      clause = by_key.clause
      by_key = by_key.key or @primary_key

    if type(by_key) == "table" and by_key[1] != "raw"
      error "#{@table_name!} find_all must have a singular key to search"

    return {} if #ids == 0
    flat_ids = concat [@db.escape_literal id for id in *ids], ", "
    primary = @db.escape_identifier by_key
    tbl_name = @db.escape_identifier @table_name!

    query = fields .. " from #{tbl_name} where #{primary} in (#{flat_ids})"

    if where
      query ..= " and " .. @db.encode_clause where

    if clause
      if type(clause) == "table"
        assert clause[1], "invalid clause"
        clause = @db.interpolate_query unpack clause

      query ..= " " .. clause

    if res = @db.select query
      @load r for r in *res
      res

  -- find by primary key, or by table of conds
  @find: (...) =>
    first = select 1, ...
    error "#{@table_name!} trying to find with no conditions" if first == nil

    cond = if "table" == type first
      @db.encode_clause (...)
    else
      @db.encode_clause @encode_key(...)

    table_name = @db.escape_identifier @table_name!

    if result = unpack @db.select "* from #{table_name} where #{cond} limit 1"
      @load result

  -- create from table of values, return loaded object
  @create: (values, opts) =>
    error "subclass responsibility"

  -- returns true if something is using the cond
  @check_unique_constraint: (name, value) =>
    t = if type(name) == "table"
      name
    else
      { [name]: value }

    error "missing constraint to check" unless next t

    cond = @db.encode_clause t
    table_name = @db.escape_identifier @table_name!
    nil != unpack @db.select "1 from #{table_name} where #{cond} limit 1"

  @_check_constraint: (key, value, obj) =>
    return unless @constraints
    if fn = @constraints[key]
      fn @, value, key, obj

  @paginated: (...) =>
    OffsetPaginator @, ...

  -- alternative to MoonScript inheritance
  @extend: (table_name, tbl={}) =>
    lua = require "lapis.lua"

    class_fields = {
      "primary_key", "timestamp", "constraints", "relations"
    }

    lua.class table_name, tbl, @, (cls) ->
      cls.table_name = -> table_name
      for f in *class_fields
        cls[f] = tbl[f]
        cls.__base[f] = nil

  _primary_cond: =>
    cond = {}
    for key in *{@@primary_keys!}
      val = @[key]
      val = @@db.NULL if val == nil

      cond[key] = val

    cond

  url_key: => concat [@[key] for key in *{@@primary_keys!}], "-"

  delete: =>
    res = @@db.delete @@table_name!, @_primary_cond!
    res.affected_rows and res.affected_rows > 0, res

  -- thing\update "col1", "col2", "col3"
  -- thing\update {
  --   "col1", "col2"
  --   col3: "Hello"
  -- }
  update: (first, ...) =>
    error "subclass responsibility"

  -- reload fields on the instance
  refresh: (fields="*", ...) =>
    local field_names

    if fields != "*"
      field_names = {fields, ...}
      fields = table.concat [@@db.escape_identifier f for f in *field_names], ", "

    cond = @@db.encode_clause @_primary_cond!
    tbl_name = @@db.escape_identifier @@table_name!
    res = unpack @@db.select "#{fields} from #{tbl_name} where #{cond}"

    unless res
      error "#{@@table_name!} failed to find row to refresh from, did the primary key change?"

    if field_names
      for field in *field_names
        @[field] = res[field]
    else
      relations = require "lapis.db.model.relations"

      if loaded_relations = @[relations.LOADED_KEY]
        for name in pairs loaded_relations
          relations.clear_loaded_relation @, name

      for k,v in pairs @
        @[k] = nil

      for k,v in pairs res
        @[k] = v

      @@load @

    @

{ :BaseModel, :Enum, :enum }
