local current
current = function()
  if ngx then
    return "nginx"
  end
  return error("can't find ngx")
end
return {
  current = current
}
