local default_environment
do
  local _obj_0 = require("lapis.cmd.util")
  default_environment = _obj_0.default_environment
end
local old_getter, old_backend
local push
push = function(name)
  if name == nil then
    name = default_environment()
  end
  assert(not old_getter, "environment already pushed")
  local config_module = require("lapis.config")
  old_getter = config_module.get
  local config = old_getter(name)
  config_module.get = function()
    return config
  end
  local pg_config = config.postgres
  if pg_config and pg_config.backend == "pgmoon" then
    local logger = require("lapis.db").get_logger()
    if not (os.getenv("LAPIS_SHOW_QUERIES")) then
      logger = nil
    end
    local db = require("lapis.nginx.postgres")
    local Postgres
    do
      local _obj_0 = require("pgmoon")
      Postgres = _obj_0.Postgres
    end
    local pgmoon
    old_backend = db.set_backend("raw", function(...)
      if not (pgmoon) then
        pgmoon = Postgres(pg_config)
        assert(pgmoon:connect())
      end
      if logger then
        logger.query(...)
      end
      return assert(pgmoon:query(...))
    end)
  end
end
local pop
pop = function()
  assert(old_getter())
  local config_module = require("lapis.config")
  config_module.get = old_getter
  old_getter = nil
  local db = require("lapis.nginx.postgres")
  db.set_backend("raw", old_backend)
  old_backend = nil
end
return {
  push = push,
  pop = pop
}
