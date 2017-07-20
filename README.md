# Lapis

A web framework for Lua/[MoonScript][1].

[![Build Status](https://travis-ci.org/leafo/lapis.svg?branch=master)](https://travis-ci.org/leafo/lapis)

Lapis is production ready, use it on your next huge project.

### <http://leafo.net/lapis/>

* [Getting Started Tutorial](http://leafo.net/lapis/reference/getting_started.html)
* [Documentation](http://leafo.net/lapis/reference.html)
* [Changelog](http://leafo.net/lapis/changelog.html)

## Lapis Powered

  * <http://luarocks.org> - [source](https://github.com/leafo/moonrocks-site)
  * <http://itch.io>
  * <http://streak.club> - [source](https://github.com/leafo/streak.club)
  * <http://mundodescuento.com/>
  * [Ludum Dare game browser](http://ludumdare.itch.io) - [source](https://github.com/leafo/ludum-dare-browser)
  * <https://pasta.cf/> - [source](https://github.com/starius/pasta)
  * <http://lapchan.moe/> - [source](https://github.com/karai17/lapis-chan/)

## Running Tests

If you need to run tests outside of our CI. The test suites require
[Busted][2] and [MoonScript][1]. There are three separate test suites:

* `busted` -- test Lua implementations
* `busted spec_postgres` -- integration tests with PostgreSQL. Requires a running PostgreSQL server
* `busted spec_mysql` -- integration tests with MySQL. Requires a running MySQL server
* `busted spec_openresty/` -- integration tests with OpenResty. Requires installation of OpenResty & Databases

Test suties that require databases need to have the initial database created. A `lapis_test` database is created on each.
You can run each command respectively.

```bash
make test_db # postgres test db
make mysql_test_db
```

* **PostgreSQL**: Ensure the `postgres` user can be logged in with no password.
* **MySQL**: Ensure the `root` user can be logged in with no password.

## License (MIT)

Copyright (C) 2017 by Leaf Corcoran

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

