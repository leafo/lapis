
require "moon"
require "lapis.init"

class Cool extends lapis.Application
  [home: "/"]: =>
    @html ->
      html_5 ->
        pre "hello world!"

  "/cool": =>
    "so cool!"

lapis.serve Cool, 6789

