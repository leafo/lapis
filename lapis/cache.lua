local json = require("cjson")
local sort, concat
do
  local _obj_0 = table
  sort, concat = _obj_0.sort, _obj_0.concat
end
local default_dict_name = "page_cache"
local cache_key
cache_key = function(path, params, r)
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
local get_dict
get_dict = function(dict_name, ...)
  local _exp_0 = type(dict_name)
  if "string" == _exp_0 then
    return ngx.shared[dict_name]
  elseif "function" == _exp_0 then
    return dict_name(...)
  else
    return dict_name
  end
end
local cached
cached = function(fn_or_tbl)
  local fn = fn_or_tbl
  local exptime = 0
  local dict_name = default_dict_name
  local _cache_key = cache_key
  local cond = nil
  if type(fn) == "table" then
    exptime = fn.exptime or exptime
    dict_name = fn.dict or dict_name
    cond = fn.when
    _cache_key = fn.cache_key or _cache_key
    fn = fn[1]
  end
  return function(self)
    if (self.req.cmd_mth ~= "GET") or (cond and not cond(self)) then
      return fn(self)
    end
    local key = _cache_key(self.req.parsed_url.path, self.GET, self)
    local dict = get_dict(dict_name, self)
    do
      local cache_value = dict:get(key)
      if cache_value then
        ngx.header["x-memory-cache-hit"] = "1"
        cache_value = json.decode(cache_value)
        return cache_value
      end
    end
    self:write(fn(self))
    self:render()
    local cache_response = {
      {
        content_type = self.res.headers["Content-type"],
        layout = false,
        status = self.res.status
      },
      self.res.content
    }
    dict:set(key, json.encode(cache_response), exptime)
    ngx.header["x-memory-cache-save"] = "1"
    self.options = { }
    self.buffer = { }
    self.res.content = nil
    return cache_response
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
  escape_pattern = require("lapis.util").escape_pattern
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
