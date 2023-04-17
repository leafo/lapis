local argparser
argparser = function()
  do
    local _with_0 = require("argparse")("lapis generate nginx.config", "Generate a templated nginx config file")
    _with_0:flag("--etlua", "Use etlua for templating file")
    return _with_0
  end
end
local initial_nginx = [[worker_processes ${{NUM_WORKERS}};
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
local convert_to_etlua
convert_to_etlua = function()
  local compile_config
  compile_config = require("lapis.cmd.nginx").compile_config
  local env = setmetatable({ }, {
    __index = function(self, key)
      return "<%- " .. tostring(key:lower()) .. " %>"
    end
  })
  return compile_config(initial_nginx, env, {
    os_env = false,
    header = false
  })
end
local write
write = function(self, args)
  local config_path, config_path_etlua
  do
    local _obj_0 = require("lapis.cmd.nginx").nginx_runner
    config_path, config_path_etlua = _obj_0.config_path, _obj_0.config_path_etlua
  end
  if args.etlua then
    return self:write(config_path_etlua, convert_to_etlua())
  else
    return self:write(config_path, initial_nginx)
  end
end
return {
  argparser = argparser,
  write = write
}
