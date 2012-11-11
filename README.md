# Lapis

A web framework for Lua/MoonScript.


```moonscript
lapis = require "lapis.init"

lapis.serve class extends lapis.Application
  "/": =>
    profile_url = @url_for "user_profile", name: "leafo"
    @html ->
      h2 "Welcome!"
      text "Go to my "
      a href: profile_url, "profile"

  [user_profile: "/:name"]: =>
    @html ->
      div class: "profile", ->
        text "Welcome to the profile of ", @params.name
```
