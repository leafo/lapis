get_sleep = ->
  current_server = package.loaded["lapis.running_server"]

  if current_server == "cqueues"
    return require("cqueues").sleep

  if ngx
    return ngx.sleep

  require("socket").sleep

{
  sleep: get_sleep!
}


