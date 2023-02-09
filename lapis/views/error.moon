html = require "lapis.html"

accept_json = =>
  if accept = @req.headers.accept
    switch type accept
      when "string"
        return true if accept\lower!\match "application/json"
      when "table"
        for v in *accept
          return true if v\lower!\match "application/json"

  false


class ErrorPage extends html.Widget
  style: =>
    style type: "text/css", ->
      raw [[
        body {
          color: #222;
          background: #ddd;
          font-family: sans-serif;
          margin: 20px;
        }

        h1, h2, pre {
          margin: 20px;
        }

        pre {
          white-space: pre-wrap;
        }

        .box {
          background: white;
          overflow: hidden;
          box-shadow: 1px 1px 8px gray;
          border-radius: 1px;
        }

        .footer {
          text-align: center;
          font-family: serif;
          margin: 10px;
          font-size: 12px;
          color: #A7A7A7;
        }
      ]]

  content: =>
    -- why do we render json object in widget? @app.error_page should be the
    -- only entry point to displaying an error so the end-user can easily
    -- overwrite it and not worry about leaking any data outside of this
    -- default error page
    if accept_json @
      import to_json from require "lapis.util"
      @res.headers["Content-Type"] = "application/json"
      raw to_json {
        error: @err
        traceback: @trace
        lapis: {
          version: require "lapis.version"
        }
      }
      return

    html_5 ->
      head ->
        meta charset: "UTF-8"
        title "Error"
        @style!
      body ->
        div class: "box", ->
          h1 "Error"
          pre ->
            text @err

          h2 "Traceback"
          pre ->
            text @trace

        version = require "lapis.version"
        div class: "footer", "lapis #{version}"

