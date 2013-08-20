local mock_request
mock_request = function(app, url, get, post)
  if get == nil then
    get = { }
  end
  if post == nil then
    post = { }
  end
  local insert, concat
  do
    local _obj_0 = table
    insert, concat = _obj_0.insert, _obj_0.concat
  end
  local old_ngx = ngx
  local nginx = require("lapis.nginx")
  local buffer = { }
  local flatten
  flatten = function(tbl, accum)
    if accum == nil then
      accum = { }
    end
    for _index_0 = 1, #tbl do
      local thing = tbl[_index_0]
      if type(thing) == "table" then
        flatten(thing, accum)
      else
        insert(accum, thing)
      end
    end
    return accum
  end
  ngx = {
    print = function(...)
      local args = flatten({
        ...
      })
      local str
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #args do
          local a = args[_index_0]
          _accum_0[_len_0] = tostring(a)
          _len_0 = _len_0 + 1
        end
        str = _accum_0
      end
      for _index_0 = 1, #args do
        local a = args[_index_0]
        insert(buffer, a)
      end
      return true
    end,
    say = function(...)
      ngx.print(...)
      return ngx.print("\n")
    end
  }
  local response = nginx.dispatch(app)
  ngx = old_ngx
  return concat(buffer)
end
return {
  mock_request = mock_request
}
