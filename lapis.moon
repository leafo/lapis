
require "moon"
require "lapis.init"

-- import Router from lapis.router
-- 
-- r = Router!
-- 
-- with r
--   \add_route home: "/"
--   \add_route dad: "/dad"
--   \add_route { user: "/user/:id" }, -> print "hello from user"
-- 
-- r\resolve "/user/34343"
-- 
-- -- p r\url_for "user", id: 2323

class Cool extends lapis.Application
  [home: "/"]: =>
    {
      "Hello"
      "<pre>"
      moon.dump self
      "</pre>"
    }

  "/cool": =>
    "so cool!"

lapis.serve Cool, 6789


