# Lapis

A web framework for Lua/MoonScript.

```bash
$ lapis new
->	wrote	nginx.conf
->	wrote	mime.types
```

```moonscript
-- web.moon
lapis = require "lapis.init"

lapis.serve class extends lapis.Application
  "/": =>
    profile_url = @url_for "user_profile", name: "leafo"
    @html ->
      h2 "Welcome!"
      text "Go to my "
      a href: profile_url, "profile"

  ⁣[user_profile: "/:name"]: =>
    @html ->
      div class: "profile", ->
        text "Welcome to the profile of ", @params.name
```

```bash
$ moonc web.moon
$ lapis server
```

## Lapis Powered

  * <http://rocks.moonscript.org>
  * <http://itch.io>


## License (MIT)

Copyright (C) 2013 by Leaf Corcoran

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

