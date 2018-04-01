http_headers = require "http.headers"
import parse_query_string from require "lapis.util"

filter_array = (t) ->
  return unless t
  for k=#t,1,-1
    t[k] = nil
  t

headers_proxy_mt = {
  __index: (name) => @[1]\get name\lower!
  __tostring: => "<HeadersProxy>"
}

request_mt = {
  __index: (name) =>
    error "Request has no implementation for: #{name}"
}

build_request = (stream) ->
  req_headers = assert stream\get_headers!
  uri = req_headers\get ":path"

  -- TODO: limit max number of entries in get table
  path, query = uri\match "^([^?]+)%?(.*)$"
  path or= uri
  query = query and filter_array(parse_query_string(query)) or {}
  method = req_headers\get ":method"

  content_type = req_headers\get "content-type"

  params_post = if content_type == "application/x-www-form-urlencoded"
    -- TODO: limits for body length
    body = stream\get_body_as_string!\gsub "+", " "
    body and filter_array(parse_query_string(body)) or {}

  h = req_headers\get ":authority"
  host, port = h\match "^(.-):(%d+)$"
  host or= h

  scheme = stream\checktls! and "https" or "http"

  family, remote_addr = stream\peername()

  setmetatable {
    -- deprecated fields
    cmd_mth: method
    cmd_url: uri
    --

    method: method
    request_uri: uri
    :remote_addr
    :scheme
    :port

    headers: setmetatable { req_headers }, headers_proxy_mt

    read_body_as_string: ->
      stream\get_body_as_string!

    params_get: query
    params_post: params_post or {}
    parsed_url: {
      :scheme
      :path, :query
      :host
      :port
    }
  }, request_mt

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
  res_headers\append ":status", res.status and string.format("%d", res.status) or "200"

  for k,v in pairs res.headers
    res_headers\append k,v

  stream\write_headers res_headers, not res.content

  if res.content
    stream\write_chunk res.content, true

  res

{ :dispatch }


