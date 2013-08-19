
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
  dict = ngx.shared[dict_name]
  dict\delete "key"

{ :cached }
