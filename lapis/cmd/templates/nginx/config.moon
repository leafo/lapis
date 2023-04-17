
argparser = ->
  with require("argparse") "lapis generate nginx.config", "Generate a templated nginx config file"
    \flag "--etlua", "Use etlua for templating file"

initial_nginx = [[
worker_processes ${{NUM_WORKERS}};
error_log stderr notice;
daemon off;
pid logs/nginx.pid;

events {
  worker_connections 1024;
}

http {
  include mime.types;

  init_by_lua_block {
    require "lpeg"
  }

  server {
    listen ${{PORT}};
    lua_code_cache ${{CODE_CACHE}};

    location / {
      default_type text/html;
      content_by_lua_block {
        require("lapis").serve("app")
      }
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

convert_to_etlua = ->
  import compile_config from require "lapis.cmd.nginx"
  env = setmetatable {}, __index: (key) => "<%- #{key\lower!} %>"
  compile_config initial_nginx, env, os_env: false, header: false

write = (args) =>
  import config_path, config_path_etlua from require("lapis.cmd.nginx").nginx_runner

  if args.etlua
    @write config_path_etlua, convert_to_etlua!
  else
    @write config_path, initial_nginx

{:argparser, :write}
