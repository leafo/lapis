http_headers = require "http.headers"
import parse_query_string from require "lapis.util"

filter_array = (t) ->
  return unless t
  for k=#t,1,-1
    t[k] = nil
  t

build_request = (stream) ->
  req_headers = assert stream\get_headers!
  url = req_headers\get ":path"

  -- TODO: limit max number of entries in get table
  path, query = url\match "^([^?]+)%?(.*)$"
  path or= url
  query = query and filter_array(parse_query_string(query)) or {}
  method = req_headers\get ":method"

  body = stream\get_body_as_string!\gsub "+", " "
  post = body and filter_array(parse_query_string(body)) or {}


  setmetatable {
    body: body
    cmd_mth: method
    cmd_url: url
    params_get: query
    params_post: post
    parsed_url: {
      scheme: "http"
      :path, :query
      host: req_headers\get "host"
      port: "8080"
    }
  }, {
    __index: (name) =>
      print "Getting", name
  }

build_response = (stream) ->
  {
    req: build_request stream
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


dispatch = (app, server, stream) ->
  res = build_response stream
  app\dispatch res.req, res

  res_headers = http_headers.new!
  res_headers\append ":status", res.status and tostring(res.status) or "200"

  for k,v in pairs res.headers
    res_headers\append k,v

  stream\write_headers res_headers, not res.content

  if res.content
    stream\write_chunk res.content, true

  res

{ :dispatch }


