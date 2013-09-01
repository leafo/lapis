-- Add the following to your http block in nginx config:
--
-- lua_shared_dict page_cache 15m;
--

json = require "cjson"

import sort, concat from table

cache_key = (path, params) ->
  params = [k.. ":" .. v for k,v in pairs params]
  sort params
  params = concat params, "-"
  path .. "#" .. params

cached = (dict_name, fn) ->
  unless type(fn) == "function"
    fn = dict_name
    dict_name = "page_cache"

  =>
    key = cache_key @req.parsed_url.path, @GET

    dict = ngx.shared[dict_name]

    if cache_value = dict\get key
      ngx.header["x-memory-cache-hit"] = "1"
      cache_value = json.decode(cache_value)
      return cache_value

    old_render = @render
    @render = (...) =>
      old_render @, ...
      -- this is done like this because you can't mix hash/array in json
      to_cache = json.encode {
        {
          content_type: @res.headers["Content-type"]
          layout: false -- layout is already part of content
        }
        @res.content
      }
      dict\set key, to_cache
      ngx.header["x-memory-cache-save"] = "1"
      nil

    fn @

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
