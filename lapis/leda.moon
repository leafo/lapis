import escape_pattern, parse_content_disposition, build_url, parse_query_string from require "lapis.util"
import parseUrl, parseQuery from require 'leda.client'

parse_url = parseUrl
parse_query = parsQuery


flatten_params = (t) -> 
    {k, type(v) == "table" and v[#v] or v for k,v in pairs t}
      
request = {
  headers: -> __leda.httpRequestGetHeaders(__leda.httpRequest) 
  cmd_mth: -> __leda.httpRequestGetMethod(__leda.httpRequest) 
  cmd_url: ->  __leda.httpRequestGetUrl(__leda.httpRequest) 
  relpath: (t) -> t.parsed_url.path
  scheme: (t)-> t.parsed_url.scheme
  port: (t) -> t.parsed_url.port
  srv: -> t.parsed_url.host
  remote_addr: -> __leda.httpRequestGetAddress(__leda.httpRequest) 
  referer: ->  ""
  body: -> __leda.httpRequestGetBody(__leda.httpRequest) 

  parsed_url: (t) ->
      
    host = t.headers.host
    parsed = parse_url(t.cmd_url)
    if host  
        parsed_host = parse_url(host)
        parsed.host = parsed_host.host
        parsed.port = parsed_host.port

    parsed
    
  built_url: (t) ->
    build_url t.parsed_url

  params_post: (t) ->
    -- parse multipart if required
    if  (t.headers["content-type"] or "")\match escape_pattern "x-www-form-urlencoded"
        flatten_params parse_query(t.body or "") or {}
    else
        flatten_params {}
        
  params_get: (t) ->
        flatten_params t.parsed_url.params
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
  with t = lazy_tbl {}, request
    if unlazy
      for k in pairs request
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
    if __leda.init
        config = require("lapis.config")
      
        -- start the leda server
        __api.serverCreate({
            type: 'http',
            port: config.get!.port,
            host: config.get!.host or 'localhost',
            threads: __leda.processorCount()
            })
        return
    else
        -- set request callback
        if not __leda.onHttpRequest 
            __leda.onHttpRequest = ->
                  dispatch(app) 
            return      
        
    res = build_response!

    app\dispatch res.req, res
    
    if res.status 
      __leda.httpResponseSetStatus(__leda.httpResponse, tonumber(res.status))
    
    if next(res.headers) 
       __leda.httpResponseSetHeaders(__leda.httpResponse, res.headers)

    if res.content 
      __leda.httpResponseSetBody(__leda.httpResponse, res.content)
        
    res

{ :build_request, :build_response, :dispatch }