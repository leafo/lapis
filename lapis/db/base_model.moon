import underscore, escape_pattern, uniquify, singularize from require "lapis.util"
import insert, concat from table

import require, type, setmetatable, rawget, assert, error, next, select from _G

unpack = unpack or table.unpack

cjson = require "cjson"

import add_relations, mark_loaded_relations, relation_is_loaded from require "lapis.db.model.relations"

_all_same = (array, val) ->
  for item in *array
    return false if item != val

  true

-- multi-key table
_get = (t, front, ...) ->
  if ... == nil
    t[front]
  else
    if obj = t[front]
      _get obj, ...
    else
      nil

_put = (t, value, front, ...) ->
  if ... == nil
    return if front == nil
    t[front] = value
    t
  else
    obj = t[front]

    if obj == nil
      obj = {}
      t[front] = obj

    _put obj, value, ...

-- _fields obj, {"a", "b", "c"} --> obj.a, obj.b, obj.c
_fields = (t, names, k=1, len=#names) ->
  if k == len
    t[names[k]]
  else
    t[names[k]], _fields(t, names, k + 1, len)

filter_duplicate_lists = (db, lists) ->
  seen = {}
  out = for list in *lists
    flat = db.escape_literal list
    continue if seen[flat]
    seen[flat] = true
    list

  out

class Enum
  debug = =>
    "(contains: #{concat ["#{i}:#{v}" for i, v in ipairs @], ", "})"

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
  @relation_models_module: "models"
  @db: nil -- set in implementing class

  @timestamp: false
  @primary_key: "id"

  @__inherited: (child) =>
    if r = rawget child, "relations"
      add_relations child, r, @db

  @get_relation_model: (model_name) =>
    switch type model_name
      when "function"
        model_name!
      when "string"
        require(@relation_models_module)[model_name]
      when "table" -- probably already a relation model class
        assert model_name == model_name.__class,
          "Got an unknown table instead of a model class for relation"

        model_name

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
      if not @db.is_encodable last
        opts = last
        param_count -= 1

    if @db.is_clause query
      query = "WHERE #{@db.encode_clause query}"
    elseif type(query) == "table"
      opts = query
      query = ""

    if param_count > 0
      query = @db.interpolate_query query, ...

    tbl_name = @db.escape_identifier @table_name!

    load_as = opts and opts.load
    fields = opts and opts.fields or "*"

    if res = @db.select "#{fields} FROM #{tbl_name} #{query}"
      return res if load_as == false
      if load_as
        load_as\load_all res
      else
        @load_all res

  @count: (clause, ...) =>
    tbl_name = @db.escape_identifier @table_name!
    query = "COUNT(*) AS c FROM #{tbl_name}"

    if clause
      switch type clause
        when "string"
          query ..= " WHERE " .. @db.interpolate_query clause, ...
        when "table"
          query ..= " WHERE #{@db.encode_clause clause}"
        else
          error "Model.count: Got unknown type for filter clause (#{type clause})"

    unpack(@db.select query).c

  -- NOTE: flip & local_key are deprecated
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
    return unless next other_records

    fields = opts and opts.fields or "*"
    flip = opts and opts.flip
    many = opts and opts.many
    value_fn = opts and opts.value
    load_rows = if opts and opts.load == false then false else true
    skip_included = opts and opts.skip_included
    for_relation = opts and opts.for_relation

    -- source_key fields on the model to fetch
    -- dest_key fields on the records we have (other_records)
    local source_key, dest_key

    name_from_table = false

    if type(foreign_key) == "table"
      if flip
        error "Model.include_in: flip can not be combined with table foreign key"

      name_from_table = true

      source_key = {}
      dest_key = {}

      for k,v in pairs foreign_key
        insert source_key, v
        insert dest_key, type(k) == "number" and v or k
    else
      source_key = if flip
        -- we use id as a default since we don't have accurate primary key for
        -- model of other_records (might be mixed)
        opts.local_key or "id"
      else
        foreign_key

      dest_key = if flip
        foreign_key
      else
        if type(@primary_key) == "table"
          error "Model.include_in: #{@table_name!} must have singular primary key for include_in"

        @primary_key

    -- the field name on the other_records to set the associated object to
    field_name = if opts and opts.as
      opts.as
    elseif flip or name_from_table
      if many
        @table_name!
      else
        @singular_name!
    elseif type(@primary_key) == "string"
      foreign_key\match "^(.*)_#{escape_pattern(@primary_key)}$"

    assert field_name, "Model.include_in: failed to infer field name, provide one with `as`"

    composite_foreign_key = if type(source_key) == "table"
      if #source_key == 1 and #dest_key == 1
        source_key = source_key[1]
        dest_key = dest_key[1]
        false
      else
        true
    else
      false

    include_ids = for record in *other_records
      if skip_included
        if for_relation
          continue if relation_is_loaded record, for_relation
        else
          continue if record[field_name] != nil

      if composite_foreign_key
        tuple = [record[k] or @db.NULL for k in *source_key]
        continue if _all_same tuple, @db.NULL
        @db.list tuple
      else
        with id = record[source_key]
          continue unless id

    if next include_ids
      if composite_foreign_key
        include_ids = filter_duplicate_lists @db, include_ids
      else
        include_ids = uniquify include_ids

      find_by_fields = if composite_foreign_key
        @db.list dest_key
      else
        dest_key

      tbl_name = @db.escape_identifier @table_name!

      -- the list of objects to find
      clause = {
        [find_by_fields]: @db.list include_ids
      }

      buffer = {
        fields
        " FROM "
        tbl_name
        " WHERE "
      }

      if opts and opts.where and next opts.where
        where = opts.where

        unless @db.is_clause opts.where
          where = @db.clause where

        clause = @db.clause {
          @db.clause clause
          where
        }

      @db.encode_clause clause, buffer

      if group = opts and opts.group
        insert buffer, " GROUP BY "
        insert buffer, group

      if order = many and opts.order
        insert buffer, " ORDER BY "
        insert buffer, order

      query = concat buffer

      if res = @db.select query
        -- holds all the fetched rows indexed by the dest_key (what was searched by)
        records = {}

        for t in *res
          row = if load_rows
            @load t
          else
            t

          row = value_fn row if value_fn

          if many
            if composite_foreign_key
              array = _get records, _fields t, dest_key

              if array
                insert array, row
              else
                _put records, {
                  row
                }, _fields t, dest_key

            else
              t_key = t[dest_key]
              unless t_key
                error "Model.include_in: query returnd a row that is missing the joining field (#{tbl_name}: #{dest_key})"

              if records[t_key] == nil
                records[t_key] = {}

              insert records[t_key], row

          else
            if composite_foreign_key
              _put records, row, _fields t, dest_key
            else
              records[t[dest_key]] = row


        -- load the rows into we feteched into the models
        if composite_foreign_key
          for other in *other_records
            other[field_name] = _get records, _fields other, source_key

            if many and not other[field_name]
              other[field_name] = {}
        else
          for other in *other_records
            other[field_name] = records[other[source_key]]

            if many and not other[field_name]
              other[field_name] = {}

        if for_relation
          mark_loaded_relations other_records, for_relation

        if callback = opts and opts.loaded_results_callback
          callback res

    other_records

  @find_all: (ids, by_key=@primary_key) =>
    local extra_where, clause, fields

    -- parse opts
    if type(by_key) == "table" and not @@db.is_encodable by_key
      fields = by_key.fields or fields
      extra_where = by_key.where
      clause = by_key.clause
      by_key = by_key.key or @primary_key

    -- TODO: we can support composite keys here
    if type(by_key) == "table" and not @@db.is_raw by_key
      error "Model.find_all: (#{@table_name!}) Must have a singular key to search"

    return {} if #ids == 0

    where = { [by_key]: @db.list ids }
    if extra_where
      if @db.is_clause extra_where
        table.insert where, extra_where
        where = @db.clause where
      else
        for k,v in pairs extra_where
          where[k] = v

    query = "WHERE " .. @db.encode_clause where

    if clause
      if type(clause) == "table"
        assert clause[1], "invalid clause"
        clause = @db.interpolate_query unpack clause

      query ..= " " .. clause

    @select query, fields: fields

  -- find by primary key, or by table of conds
  @find: (...) =>
    first = select 1, ...
    if first == nil
      error "Model.find: #{@table_name!}: trying to find with no conditions"

    cond = if "table" == type first
      @db.encode_clause (...)
    else
      @db.encode_clause @encode_key(...)

    table_name = @db.escape_identifier @table_name!

    if result = unpack @db.select "* FROM #{table_name} WHERE #{cond} LIMIT 1"
      @load result
    else
    	nil

  -- create from table of values, return loaded object
  -- NOTE: this implementation depends on support for RETURNING sql synax
  @create: (values, opts) =>
    if @constraints
      for key in pairs @constraints
        if err = @_check_constraint key, values and values[key], values
          return nil, err

    if @timestamp
      time = @db.format_date!
      values.created_at or= time
      values.updated_at or= time

    local returning, return_all, nil_fields

    if opts and opts.returning
      if opts.returning == "*"
        return_all = true
        returning = { @db.raw "*" }
      else
        returning = { @primary_keys! }
        for field in *opts.returning
          table.insert returning, field

    for k, v in pairs values
      if v == @db.NULL
        nil_fields or= {}
        nil_fields[k] = true
        continue
      elseif not return_all and @db.is_raw v
        returning or= {@primary_keys!}
        table.insert returning, k

    res = if returning
      @db.insert @table_name!, values, unpack returning
    else
      @db.insert @table_name!, values, @primary_keys!

    if res
      if returning and not return_all
        for k in *returning
          values[k] = res[1][k]

      for k,v in pairs res[1]
        values[k] = v

      if nil_fields
        for k in pairs nil_fields
          values[k] = nil

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

    cond = @db.encode_clause t
    table_name = @db.escape_identifier @table_name!
    nil != unpack @db.select "1 from #{table_name} where #{cond} limit 1"

  @_check_constraint: (key, value, obj) =>
    return unless @constraints
    if fn = @constraints[key]
      fn @, value, key, obj

  @paginated: (...) =>
    nargs = select "#", ...

    local fetch_opts

    fetch_opts = if nargs > 1
      last_arg = select nargs, ...
      if last_arg and type(last_arg) == "table"
        last_arg

    if fetch_opts and fetch_opts.ordered
      import OrderedPaginator from require "lapis.db.pagination"
      args = {...}
      args[nargs] = {k,v for k,v in pairs fetch_opts when k != "ordered"}
      OrderedPaginator @, fetch_opts.ordered, unpack args
    else
      import OffsetPaginator from require "lapis.db.pagination"
      OffsetPaginator @, ...

  @extend: (table_name, tbl={}) =>
    lua = require "lapis.lua"

    class_fields = {
      "primary_key", "timestamp", "constraints", "relations"
    }

    cls = lua.class table_name, tbl, @, (cls) ->
      cls.table_name = -> table_name
      for f in *class_fields
        cls[f] = tbl[f]
        cls.__base[f] = nil

    cls, cls.__base

  _primary_cond: =>
    cond = {}
    for key in *{@@primary_keys!}
      val = @[key]
      val = @@db.NULL if val == nil

      cond[key] = val

    cond

  url_key: => concat [@[key] for key in *{@@primary_keys!}], "-"

  delete: (...) =>
    cond = @_primary_cond!

    rest_idx = 1

    if @@db.is_clause (...)
      rest_idx = 2
      cond = @@db.clause {
        @@db.clause cond
        (...)
      }

    res = @@db.delete @@table_name!, cond, select rest_idx, ...

    (res.affected_rows or 0) > 0, res

  -- thing\update "col1", "col2", "col3"
  -- thing\update {
  --   "col1", "col2"
  --   col3: "Hello"
  -- }
  -- NOTE: this implementation depends on support for RETURNING sql synax
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

    if opts and opts.where
      assert type(opts.where) == "table", "Model.update: where condition must be a table or db.clause"

      where = if @@db.is_clause opts.where
        opts.where
      else
        @@db.encode_clause opts.where

      cond = @@db.clause {
        @@db.clause cond
        where
      }

    local returning
    for k, v in pairs values
      if v == @@db.NULL
        @[k] = nil
      elseif @@db.is_raw(v)
        returning or= {}
        table.insert returning, k

    local res

    if returning
      res = @@db.update @@table_name!, values, cond, unpack returning
      if update = unpack res
        for k in *returning
          @[k] = update[k]
    else
      res = @@db.update @@table_name!, values, cond

    (res.affected_rows or 0) > 0, res


  -- reload fields on the instance
  refresh: (fields="*", ...) =>
    local field_names

    if fields != "*"
      field_names = {fields, ...}
      fields = concat [@@db.escape_identifier f for f in *field_names], ", "

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
