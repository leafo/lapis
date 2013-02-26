return [[worker_processes  ${{NUM_WORKERS}};
error_log stderr notice;
daemon off;
env LAPIS_ENVIRONMENT;

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
            set $_url "";
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
]]
