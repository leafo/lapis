html = require "lapis.html"
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
    html_5 ->
      head ->
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



