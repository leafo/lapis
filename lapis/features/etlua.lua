local loadkit = require("loadkit")
local EtluaWidget
EtluaWidget = require("lapis.etlua").EtluaWidget
return loadkit.register("etlua", function(file, mod, fname)
  local widget, err = EtluaWidget:load(file:read("*a"))
  if err then
    error("[" .. tostring(fname) .. "] " .. tostring(err))
  end
  return widget
end)
