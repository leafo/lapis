import RouteParser from require "lapis.router"
parser = RouteParser!

parse\parse ":thing-hello"
p = parser\parse ":thing(-:hello)"

require("moon").p {
  p
}



