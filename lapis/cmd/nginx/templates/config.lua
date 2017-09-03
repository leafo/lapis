return [[worker_processes ${{NUM_WORKERS}};
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
]]
