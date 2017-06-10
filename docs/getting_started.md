{
  title: "Getting Started With Lapis"
}
# Getting Started With Lapis

[Lapis](http://leafo.net/lapis/) is a web framework written for Lua and
MoonScript. Lapis is interesting because it's built on top of the Nginx
distribution [OpenResty][0]. Your web application is run directly inside of
Nginx. Nginx's event loop lets you make asynchronous HTTP requests, database
queries and other requests using the modules provided with OpenResty. Lua's
coroutines allow you to write synchronous looking code that is event driven
behind the scenes.

In addition to providing a web framework, Lapis also provides tools for
controlling OpenResty in different configuration environments. Even if you
don't want to use the web framework you might find it useful if you're working
with OpenResty.

The web framework comes with a URL router, HTML templating, CSRF and session
support, a PostgreSQL or MySQL backed active record system for working with
models and a handful of other useful functions needed for developing websites.

This guide hopes to serve as a tutorial and a reference.

## Basic Setup

Install OpenResty onto your system. If you're using Heroku then you can use the
[Heroku OpenResty module][4] along with the [Lua build pack][3].

Next install Lapis using LuaRocks:

```bash
$ luarocks install lapis
```

## Creating An Application

### `lapis` Command Line Tool

Lapis comes with a command line tool to help you create new projects and start
the server. To see what Lapis can do, run in your shell:


```bash
$ lapis help
```

For now though, we'll just be creating a new project. Navigate to a clean
directory and run:

```bash
$  lapis new

wrote	nginx.conf
wrote	mime.types
wrote	app.moon
```

> If you want a Lua starter application then you can pass the `--lua` flag,
> more about this in the [Lua getting started
> guide]($root/reference/lua_getting_started.html).

Lapis starts you off by writing a basic Nginx configuration and a blank Lapis
application.

Feel free to look at the generated configuration file (`nginx.conf` is the only
important file). Here's a brief overview of what it does:

 * Any requests inside `/static/` will serve files out of the directory
   `static` (You can create this directory now if you want)
 * A request to `/favicon.ico` is read from `static/favicon.ico`
 * All other requests will be served by Lua, more specifically a module named `"app"`

When you start the server using the `lapis` command line tool the `nginx.conf`
file is processed and templated variables are filled with values from the
current Lapis' environment. This is discussed in more detail further on.

### Nginx Configuration

Let's take a look at the configuration that `lapis new` has given us. Although
it's not necessary to look at this immediately, it's important to understand
when building more advanced applications or even just deploying your
application to production.

Here is the `nginx.conf` that has been generated:

```nginx
worker_processes ${{NUM_WORKERS}};
error_log stderr notice;
daemon off;
pid logs/nginx.pid;

events {
  worker_connections 1024;
}

http {
  include mime.types;

  server {
    listen ${{PORT}};
    lua_code_cache ${{CODE_CACHE}};

    location / {
      default_type text/html;
      content_by_lua '
        require("lapis").serve("app")
      ';
    }

    location /static/ {
      alias static/;
    }

    location /favicon.ico {
      alias static/favicon.ico;
    }
  }
}
```

The first thing to notice is that this is not a normal Nginx configuration
file. Special `${{VARIABLE}}` syntax is used by Lapis to inject environment
settings before starting the server.

There are a couple interesting things provided by the default configuration.
`error_log stderr notice` and `daemon off` lets our server run in the
foreground, and print log text to the console. This is great for development,
but worth turning off in a production environment.

`lua_code_cache` is also another setting useful for development. When set to
`off` it causes all Lua modules to be reloaded on each request. Modifications to
the web application's source code can then be reloaded automatically. In a
production environment the cache should be enabled (`on`) for optimal performance.
Defaults to `off`.

The `content_by_lua` directive specifies a chunk of Lua code that will handle
any request that doesn't match the other locations. It loads Lapis and tells it
to serve the module named `"app"`. The `lapis new` command ran earlier provides
a skeleton `app` module to get started with

## Starting The Server

Although it's possible to start Nginx manually, Lapis wraps building the
configuration and starting the server into a single convenient command.

Running `lapis server` in the shell will start the server. Lapis will
attempt to find your OpenResty installation. It will search the following
directories for an `nginx` binary. (The last one represents anything in your
`PATH`)

    "/usr/local/openresty/nginx/sbin/"
    "/usr/local/opt/openresty/bin/"
    "/usr/sbin/"
    ""

> Remember that you need OpenResty and not a normal installation of Nginx.
> Lapis will ignore regular Nginx binaries.


If you've been following along, go ahead and start the server to see what it
looks like:

```bash
$ lapis server
```

The default configuration puts the server in the foreground, use `CTRL+C` to
stop the server.

If the server is running in the background it can be stopped with the command
`lapis term`. It must be run in the root directory of the application.  This
command looks for the PID file for a running server and sends a `TERM` message
to that process if it exists.

## Creating An Application

Now that you know how to generate a new project and start and stop the server
you're ready to start writing application code. This guide splits into two for
MoonScript and Lua.

I recommended reading through both paths if you're unsure what you want to use.

 * [Create an application with Lua][1]
 * [Create an application with MoonScript][2]

> Further guides have MoonScript and Lua examples on the same page and can be
> toggled with the *MoonScript* and *Lua* buttons on the top right.

[0]: http://openresty.org/
[1]: lua_getting_started.html
[2]: moon_getting_started.html
[3]: https://github.com/leafo/heroku-buildpack-lua
[4]: https://github.com/leafo/heroku-openresty
