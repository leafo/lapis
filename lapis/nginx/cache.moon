-- Add the following to your http block in nginx config:
--
-- lua_shared_dict page_cache 15m;
--

json = require "cjson"

unpack = unpack or table.unpack

import sort, concat from table

default_dict_name = "page_cache"

serialize_table_value = (params) ->
  params = for k,v in pairs params
    value = switch type v
      when "table"
        serialize_table_value v
      when "string"
        v
      when "nil", "boolean"
        tostring v
      else
        error "unknown param type: #{type v}"

    tostring(k) .. ":" .. value

  sort params
  concat params, "-"

cache_key = (path, params, r) ->
  path .. "#" .. serialize_table_value params

get_dict = (dict_name, ...) ->
  switch type(dict_name)
    when "string"
      ngx.shared[dict_name]
    when "function"
      dict_name ...
    else
      dict_name

cached = (fn_or_tbl) ->
  fn = fn_or_tbl
  exptime = 0
  dict_name = default_dict_name
  _cache_key = cache_key
  cond = nil

  if type(fn) == "table"
    exptime = fn.exptime or exptime
    dict_name = fn.dict or dict_name
    cond = fn.when
    _cache_key = fn.cache_key or _cache_key

    fn = fn[1]

  =>
    if (@req.method != "GET") or (cond and not cond @)
      return fn @

    key = _cache_key @req.parsed_url.path, @GET, @
    dict = get_dict dict_name, @

    unless dict
      error "failed to load dictionary for cache: `#{dict_name}`"

    if cache_value = dict\get key
      ngx.header["x-memory-cache-hit"] = "1"
      cache_value = json.decode(cache_value)
      return cache_value

    @write fn @
    @@support.render @

    -- you can't mix hash/array in json so we make two tables
    cache_response = {
      {
        content_type: @res.headers["Content-type"]
        layout: false -- layout is already part of content
        status: @res.status
      }
      @res.content
    }

    dict\set key, json.encode(cache_response), exptime
    ngx.header["x-memory-cache-save"] = "1"

    -- reset the request
    @options = {}
    @buffer = {}
    @res.content = nil
    cache_response

delete = (key, dict_name="page_cache") ->
  if type(key) == "table"
    key = cache_key unpack key

  dict = ngx.shared[dict_name]
  dict\delete key

delete_path = (path, dict_name="page_cache") ->
  import escape_pattern from require "lapis.util"

  dict = ngx.shared[dict_name]
  for key in *dict\get_keys!
    if key\match "^" .. escape_pattern(path) .. "#"
      dict\delete key

delete_all = (dict_name="page_cache") ->
  ngx.shared[dict_name]\flush_all!

{ :cached, :delete, :delete_path, :delete_all, :cache_key }
