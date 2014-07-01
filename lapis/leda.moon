import escape_pattern, parse_content_disposition, build_url, parse_query_string from require "lapis.util"
url = require "socket.url"

flatten_params = (t) -> 
    {k, type(v) == "table" and v[#v] or v for k,v in pairs t}

to_keyvalue = (t) -> 
    r = {}
    for key, value in pairs t
        r[key] = value if type(key) == 'string'
    r  
      
ngx_req = {
  headers: -> __leda.httpRequest.headers
  cmd_mth: -> __leda.httpRequest.method
  cmd_url: ->  __leda.httpRequest.url

  relpath: (t) -> t.parsed_url.path
  scheme: -> ""
  port: (t) -> t.parsed_url.port
  srv: -> t.parsed_url.host
  remote_addr: -> __leda.httpRequest.remoteAddress
  referer: ->  ""
  body: -> __leda.httpRequest.body

  parsed_url: (t) ->
    uri = __leda.httpRequest.url
    uri = uri\match("(.-)%?") or uri
    host = __leda.httpRequest.headers.host or ""
    parsed = url.parse(__leda.httpRequest.url)
    query = parsed.query or ""
    
    {
      scheme: ""
      path: uri
      host: host
      port: host\match ":(%d+)$"
      query: query
    }

  built_url: (t) ->
    build_url t.parsed_url

  params_post: (t) ->
    -- parse multipart if required
    if  (t.headers["content-type"] or "")\match escape_pattern "x-www-form-urlencoded"
        to_keyvalue parse_query_string(t.body or "") or {}
    else
        flatten_params {}
        
  params_get: (t) ->
    -- need a way to do this better. parse_url_string returns a table like '{1={1=a,2=b},a=b}' for a string '?a=b'
    to_keyvalue parse_query_string(t.parsed_url.query) or {}
}

lazy_tbl = (tbl, index) ->
  setmetatable tbl, {
    __index: (key) =>
      fn = index[key]
      if fn
        with res = fn @
          @[key] = res
  }


build_request = (unlazy=false) ->
  with t = lazy_tbl {}, ngx_req
    if unlazy
      for k in pairs ngx_req
        t[k]

build_response = ->
  {
    req: build_request!
    add_header: (k, v) =>
      old = @headers[k]
      switch type old
        when "nil"
          @headers[k] = v
        when "table"
          old[#old + 1] = v
          @headers[k] = old
        else
          @headers[k] = {old, v}

     headers: {}
  }

dispatch = (app) ->
    res = build_response!

    app\dispatch res.req, res

    __leda.httpResponse = {
      body: res.content,
      headers: res.headers,
      status:  200
    }
    
    res

{ :build_request, :build_response, :dispatch }