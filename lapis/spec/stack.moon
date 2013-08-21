-- quick way to maintain a stack of fake ngx variables for testing

stack = {}

push = (new_ngx) ->
  joined = if ngx
    table.insert stack, ngx
    with joined = {k,v for k,v in pairs ngx}
      for k,v in pairs new_ngx
        joined[k] = v
  else
    new_ngx

  export ngx = joined

pop = ->
  export ngx = stack[#stack]
  stack[#stack] = nil

{ :push, :pop }

