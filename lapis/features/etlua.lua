local loadkit = require("loadkit")
local EtluaWidget
do
  local _obj_0 = require("lapis.etlua")
  EtluaWidget = _obj_0.EtluaWidget
end
return loadkit.register("etlua", function(file, mod, fname)
  local widget, err = EtluaWidget:load(file:read("*a"))
  if err then
    error("[" .. tostring(fname) .. "] " .. tostring(err))
  end
  return widget
end)
