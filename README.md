# Lapis

A web framework for Lua/[MoonScript][1] supporting [OpenResty](https://openresty.org/en/) or [http.server](https://github.com/daurnimator/lua-http)

![spec](https://github.com/leafo/lapis/workflows/spec/badge.svg)

Lapis is production ready, use it on your next huge project.

Learn more on the homepage: <http://leafo.net/lapis/>

* [Getting Started Tutorial](http://leafo.net/lapis/reference/getting_started.html)
* [Documentation](http://leafo.net/lapis/reference.html)
* [Changelog](http://leafo.net/lapis/changelog.html)

## Join Our Community

We just created a Discord for Lapis users and those interested in it to communicate. You can join us here: <https://discord.gg/Y75ZXrD>

## Lapis Powered

  * <https://luarocks.org> - [source](https://github.com/leafo/moonrocks-site)
  * <https://itch.io>
  * <https://streak.club> - [source](https://github.com/leafo/streak.club)
  * <https://sightreading.training> - [source](https://github.com/leafo/sightreading.training)
  * [Ludum Dare game browser](http://ludumdare.itch.io) - [source](https://github.com/leafo/ludum-dare-browser)
  * <http://lapchan.moe/> - [source](https://github.com/karai17/lapis-chan/)

Made a website in Lapis? [Tell us](https://github.com/leafo/lapis/discussions/749)

## Supplemental Libraries


* [lapis-eswidget](https://github.com/leafo/lapis-eswidget) - A widget base class designed for organizing front-end code bundling
* [lapis-annotate](https://github.com/leafo/lapis-annotate) - Autogenerate comments on models with their database schema
* [lapis-console](https://github.com/leafo/lapis-console) - Interactive MoonScript console for Lapis that runs inside of your browser
* [lapis-exceptions](https://github.com/leafo/lapis-exceptions) - Exception tracking and reporting
* [lapis-bayes](https://github.com/leafo/lapis-bayes) - General purpose Bayes classification for Spam, Fraud, etc.


## Running Tests

If you need to run tests outside of our CI. The test suites require
[Busted][2] and [MoonScript][1]. There are three separate test suites:

* `busted` -- test Lua implementations
* `busted spec_postgres` -- integration tests with PostgreSQL. Requires a running PostgreSQL server
* `busted spec_mysql` -- integration tests with MySQL. Requires a running MySQL server
* `busted spec_openresty/` -- integration tests with OpenResty as a server. Requires installation of OpenResty & Databases
* `busted spec_cqueues/` -- integration tests with [lua-http](https://github.com/daurnimator/lua-http) and cqueues as a server.

Test suites that require databases need to have the initial database created. A `lapis_test` database is created on each.
You can run each command respectively.

```bash
make test_db # postgres test db
make mysql_test_db
```

* **PostgreSQL**: Ensure the `postgres` user can be logged in with no password.
* **MySQL**: Ensure the `root` user can be logged in with no password.

### Using the Docker image

This repository contains a
[Dockerfile](https://github.com/leafo/lapis/blob/master/Dockerfile) for running
the entire test suite. You can run it with the following commands:

```bash
docker build -t lapis-test .
docker run lapis-test
```

`docker build` will pull in the files in the current directory, including any
changes. To test modified code, build again before running the test suite. It
should be a quick operation since dependency installation is cached.

 [1]: http://moonscript.org
 [2]: http://olivinelabs.com/busted/

