local json = require("cjson")
local sort, concat
do
  local _obj_0 = table
  sort, concat = _obj_0.sort, _obj_0.concat
end
local default_dict_name = "page_cache"
local cache_key
cache_key = function(path, params)
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k, v in pairs(params) do
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
cached = function(fn_or_tbl)
  local fn, exptime, dict_name = fn_or_tbl, 0, default_dict_name
  if type(fn) == "table" then
    exptime = fn.exptime or exptime
    dict_name = fn.dict or dict_name
    fn = fn_or_tbl[1]
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
      dict:set(key, to_cache, exptime)
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
  if type(key) == "table" then
    key = cache_key(unpack(key))
  end
  local dict = ngx.shared[dict_name]
  return dict:delete(key)
end
local delete_path
delete_path = function(path, dict_name)
  if dict_name == nil then
    dict_name = "page_cache"
  end
  local escape_pattern
  do
    local _obj_0 = require("lapis.util")
    escape_pattern = _obj_0.escape_pattern
  end
  local dict = ngx.shared[dict_name]
  local _list_0 = dict:get_keys()
  for _index_0 = 1, #_list_0 do
    local key = _list_0[_index_0]
    if key:match("^" .. escape_pattern(path) .. "#") then
      dict:delete(key)
    end
  end
end
local delete_all
delete_all = function(dict_name)
  if dict_name == nil then
    dict_name = "page_cache"
  end
  return ngx.shared[dict_name]:flush_all()
end
return {
  cached = cached,
  delete = delete,
  delete_path = delete_path,
  delete_all = delete_all,
  cache_key = cache_key
}
