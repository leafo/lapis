
require "moon"

import Router from require "lapis.router"
handle = (...) -> moon.p {...}

r = Router!
r.default_route = (r) => print "failed to find", r

r\add_route "/hello", handle
r\add_route "/hello/:name", handle
r\add_route "/static/*", handle


r\resolve "/hello"
r\resolve "/hello/2323"
r\resolve "/static/hello.html"


