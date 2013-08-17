local cached
cached = function(dict_name, fn)
  if not (type(fn) == "function") then
    fn = dict_name
    dict_name = "page_cache"
  end
  return function(self)
    local params
    do
      local _accum_0 = { }
      local _len_0 = 1
      for k, v in pairs(self.GET) do
        _accum_0[_len_0] = k .. ":" .. v
        _len_0 = _len_0 + 1
      end
      params = _accum_0
    end
    table.sort(params)
    params = table.concat(params, "-")
    local cache_key = self.req.parsed_url.path .. "#" .. params
    local dict = ngx.shared[dict_name]
    do
      local cache_value = dict:get(cache_key)
      if cache_value then
        ngx.header["x-memory-cache-hit"] = "1"
        cache_value = json.decode(cache_value)
        return cache_value
      end
    end
    local old_render = self.render
    self.render = function(self, ...)
      old_render(self, ...)
      local to_cache = json.encode({
        {
          content_type = self.res.headers["Content-type"],
          layout = false
        },
        self.res.content
      })
      dict:set(cache_key, to_cache)
      ngx.header["x-memory-cache-save"] = "1"
      return nil
    end
    return fn(self)
  end
end
return {
  cached = cached
}
