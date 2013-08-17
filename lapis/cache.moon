
cached = (dict_name, fn) ->
  unless type(fn) == "function"
    fn = dict_name
    dict_name = "page_cache"

  =>
    params = [k.. ":" .. v for k,v in pairs @GET]
    table.sort params
    params = table.concat params, "-"
    cache_key = @req.parsed_url.path .. "#" .. params

    dict = ngx.shared[dict_name]

    if cache_value = dict\get cache_key
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
      dict\set cache_key, to_cache
      ngx.header["x-memory-cache-save"] = "1"
      nil

    fn @



{ :cached }
