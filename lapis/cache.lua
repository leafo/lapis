local sort, concat
do
  local _obj_0 = table
  sort, concat = _obj_0.sort, _obj_0.concat
end
local cache_key
cache_key = function(path, params)
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k, v in pairs(self.GET) do
      _accum_0[_len_0] = k .. ":" .. v
      _len_0 = _len_0 + 1
    end
    params = _accum_0
  end
  sort(params)
  params = concat(params, "-")
  return path .. "#" .. params
end
local cached
cached = function(dict_name, fn)
  if not (type(fn) == "function") then
    fn = dict_name
    dict_name = "page_cache"
  end
  return function(self)
    local key = cache_key(self.req.parsed_url.path, self.GET)
    local dict = ngx.shared[dict_name]
    do
      local cache_value = dict:get(key)
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
      dict:set(key, to_cache)
      ngx.header["x-memory-cache-save"] = "1"
      return nil
    end
    return fn(self)
  end
end
local delete
delete = function(key, dict_name)
  if dict_name == nil then
    dict_name = "page_cache"
  end
  local dict = ngx.shared[dict_name]
  return dict:delete("key")
end
return {
  cached = cached
}
