local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate gitignore", "Generate a .gitignore file")
    _with_0:flag("--tup")
    _with_0:mutex(_with_0:flag("--cqueues"), _with_0:flag("--nginx"))
    _with_0:mutex(_with_0:flag("--lua"), _with_0:flag("--moonscript --moon"))
    return _with_0
  end
end
local write
write = function(self, args)
  local lines = { }
  if args.nginx then
    insert(lines, "logs/")
    insert(lines, "nginx.conf.compiled")
  end
  if args.moonscript then
    insert(lines, "*.lua")
  end
  if args.tup then
    insert(lines, ".tup")
  end
  local output = concat(lines, "\n") .. "\n"
  return self:write(".gitignore", output)
end
return {
  argparser = argparser,
  write = write
}
