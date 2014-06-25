title: Getting Started With Lapis
--
# Getting Started With Lapis

[Lapis](http://leafo.net/lapis/) is a web framework written for Lua and
MoonScript. Lapis is interesting because it's built on top of the Nginx
distribution [OpenResty][0]. Your web application is run directly inside of
Nginx. Nginx's event loop lets you make asynchronous HTTP requests, database
queries and other requests using the modules provided with OpenResty. Lua's
coroutines allows you to write synchronous looking code that is event driven
behind the scenes.

In addition to provided a web framework, Lapis also provides tools for
controlling OpenResty in different configuration environemnts. Even if you
don't want to use the web framework you might find it useful if you're working
with OpenResty.

The web framework comes with URL router, HTML templating, CSRF and session
support, a PostgreSQL backed active record system for working with models
and a handful of other useful functions needed for developing websites.

This guide hopes to serve as a tutorial and a reference.

## Basic Setup

Install OpenResty onto your system. If you're compiling manually it's
recommended to enable PostgreSQL and Lua JIT. If you're using Heroku then you
can use the Heroku OpenResty module along with the Lua build pack.

Next install Lapis using LuaRocks:

```bash
$ luarocks install lapis
```

## Creating An Application

### `lapis` Command Line Tool

Lapis comes with a command line tool to help you create new projects and start
your server. To see what Lapis can do, run in your shell:


```bash
$ lapis help
```

For now though, we'll just be creating a new project. Navigate to a clean
directory and run:

```bash
$  lapis new

->	wrote	nginx.conf
->	wrote	mime.types
```

Lapis starts you off by writing some basic Nginx configuration. Your
application runs directly in Nginx and this configuration is what routes
requests from Nginx to your Lua code.

Feel free to look at the generated configuration file (`nginx.conf` is the only
important file). Here's a brief overview of what it does:

 * Any requests inside `/static/` will serve files out of the directory
   `static` (You can create this directory now if you want)
 * A request to `/favicon.ico` is read from `static/favicon.ico`
 * All other requests will be served by `web.lua`. (We'll create this next)

When you start your server with Lapis, the `nginx.conf` file is actually
processed and templated variables are filled in based on the server's
environment. We'll talk about how to configure these things later on.

### Nginx Configuration

Let's take a look at the configuration that `lapis new` has given us. Although
it's not necessary to look at this immediately, it's important to understand
when building more advanced applications or even just deploying your
application to production.

Here is the `nginx.conf` that has been generated:

```nginx
worker_processes  ${{NUM_WORKERS}};
error_log stderr notice;
daemon off;

events {
    worker_connections 1024;
}

http {
    include mime.types;

    server {
        listen ${{PORT}};
        lua_code_cache off;

        location / {
            default_type text/html;
            content_by_lua_file "web.lua";
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

`lua_code_cache off` is also another setting nice for development. It causes
all Lua modules to be reloaded on each request, so if we change files after
starting the server they will be picked up. Something you also want to turn off
in production for the best performance.

Our single location calls the directive `content_by_lua_file "web.lua"`. This
causes all requests of that location to run through `web.lua`, so let's make
that now.

## Starting The Server

Before we start writing any code lets look at how to start the server.

To start your server you can run `lapis server`. The `lapis` binary will
attempt to find your OpenResty instalation. It will search the following
directories for an `nginx` binary. (The last one represents anything in your
`PATH`)

    "/usr/local/openresty/nginx/sbin/"
    "/usr/local/opt/openresty/bin/"
    "/usr/sbin/"
    ""

> Remember that you need OpenResty and not a normal installation of Nginx.
> Lapis will ignore regular Nginx binaries.

You can go ahead and start the server now so you can see what it looks like:

```bash
$ lapis server
```

When running the server in the foreground, which is the default for the
generated configuration, you can stop the server with `CTRL+C`

If you're running the server in the background you can run `lapis term` from
your command line in the directory of your application to stop the server. This
command looks for the PID file for a running server and sends a `TERM` message
to that process if it exists.

## Creating An Application

Now we're ready to start writing our application logic. You have a choice which
path to take depending on the language you want to learn. I recommended reading
through both paths if you're unsure what you want to use.

 * [Create an application with Lua][1]
 * [Create an application with MoonScript][2]


[0]: http://openresty.org/
[1]: lua_getting_started.html
[2]: moon_getting_started.html
