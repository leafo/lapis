local get_sleep
get_sleep = function()
  local current_server = package.loaded["lapis.running_server"]
  if current_server == "cqueues" then
    return require("cqueues").sleep
  end
  if ngx then
    return ngx.sleep
  end
  require("socket")
  return socket.sleep
end
return {
  sleep = get_sleep()
}
