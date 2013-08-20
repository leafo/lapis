
mock_request = (app, url, get={}, post={}) ->
  import insert, concat from table

  old_ngx = ngx
  nginx = require "lapis.nginx"
  buffer = {}

  flatten = (tbl, accum={})->
    for thing in *tbl
      if type(thing) == "table"
        flatten thing, accum
      else
        insert accum, thing

    accum

  export ngx = {
    print: (...) ->
      args = flatten { ... }
      str = [tostring a for a in *args]
      insert buffer, a for a in *args
      true

    say: (...) ->
      ngx.print ...
      ngx.print "\n"

  }

  response = nginx.dispatch app
  export ngx = old_ngx
  concat buffer


{ :mock_request }
