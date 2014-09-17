local stack = { }
local push
push = function(new_ngx)
  local joined
  if ngx then
    table.insert(stack, ngx)
    do
      do
        local _tbl_0 = { }
        for k, v in pairs(ngx) do
          _tbl_0[k] = v
        end
        joined = _tbl_0
      end
      for k, v in pairs(new_ngx) do
        joined[k] = v
      end
      joined = joined
    end
  else
    joined = new_ngx
  end
  ngx = joined
end
local pop
pop = function()
  ngx = stack[#stack]
  stack[#stack] = nil
end
return {
  push = push,
  pop = pop
}
