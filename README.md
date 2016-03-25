# Lapis

A web framework for Lua/[MoonScript][1].

[![Build Status](https://travis-ci.org/leafo/lapis.svg?branch=master)](https://travis-ci.org/leafo/lapis)

Lapis is production ready, use it on your next huge project.

### <http://leafo.net/lapis/>

## Lapis Powered

  * <http://luarocks.org> - [source](https://github.com/leafo/moonrocks-site)
  * <http://itch.io>
  * <http://streak.club> - [source](https://github.com/leafo/streak.club)
  * <http://mundodescuento.com/>
  * [Ludum Dare game browser](http://ludumdare.itch.io) - [source](https://github.com/leafo/ludum-dare-browser)
  * <https://pasta.cf/> - [source](https://github.com/starius/pasta)

## Running Tests

Requires [Busted][2] and [MoonScript][1].

```bash
busted
```

If you want to run the tests that query PostgreSQL, you'll need to have
PostgreSQL installed and running. Create a database called `lapis_test`, ensure
the `postgres` user can be logged in with no password.

```bash
busted spec_postgres
```

Likewise, for MySQL tests, create a database called `lapis_test`. Ensure the
`root` user can be logged in with no password.

```bash
busted spec_mysql
```

## License (MIT)

Copyright (C) 2016 by Leaf Corcoran

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

 [1]: http://moonscript.org
 [2]: http://olivinelabs.com/busted/

