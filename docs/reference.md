
# Lapis 0.2

Lapis is a web framework written in MoonScript. It is designed to be used with
MoonScript but can also works fine with Lua. Lapis is interesting because it's
built on top of the Nginx distribution [OpenResty][0]. Your web application is
run directly inside of Nginx. Nginx's event loop lets you make asynchronous
HTTP requests, database queries and other requests using the modules provided
with OpenResty. Lua's coroutines allows you to write synchronous looking code
that is event driven behind the scenes.

Lapis is early in development but it comes with a url router, html templating
through a MoonScript DSL, CSRF and session support, and a basic Postgres backed
active record system for working with models.

This guide hopes to serve as a tutorial and a reference.

## Basic Setup

Install OpenResty onto your system. If you're compiling manually it's
recommended to enable Postgres and Lua JIT. If you're using heroku then you can
use the Heroku OpenResy module along with the Lua build pack.

Next install Lapis using LuaRocks. You can find the rockspec [on MoonRocks][3]:

    luarocks install --server=http://rocks.moonscript.org/manifests/leafo lapis

## Creating An Application

To start out, create a `nginx.conf` file in a new directory. The config file
lets us control what requests go to Lua. This is powerful because we can still
serve things like static assets through Nginx, which is very performant. In
this simple example though, we only have a single location that has all
requests go to Lua.

    # nginx.conf
    worker_processes  1;
    error_log stderr notice;
    daemon off;

    events {
      worker_connections 1024;
    }

    http {
      server {
        listen 8080;
        lua_code_cache off;

        location / {
          default_type text/html;
          content_by_lua_file "web.lua";
        }
      }
    }


There are a couple interesting things here. `error_log stderr notice` and
`daemon off` lets our server run in the foreground, and print debugging text to
the console. This is great for development, but worth turning off in a
production environment.

`lua_code_cache off` is also another setting nice for development. It causes
all Lua modules to be reloaded on each request, so if we change files after
starting the server they will be picked up.


[0]: http://openresty.org/
[1]: https://github.com/leafo/heroku-openresty
[2]: https://github.com/leafo/heroku-buildpack-lua
[3]: http://rocks.moonscript.org/modules/leafo/lapis

