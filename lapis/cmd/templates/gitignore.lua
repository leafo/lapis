local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
return function(flags)
  if flags == nil then
    flags = { }
  end
  local lines = {
    "*.lua",
    "logs/",
    "nginx.conf.compiled"
  }
  if flags.tup then
    insert(lines, ".tup")
  end
  return concat(lines, "\n") .. "\n"
end
