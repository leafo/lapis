local TEST_ENV = "test"
local normalize_headers
normalize_headers = require("lapis.spec.request").normalize_headers
local ltn12 = require("ltn12")
local json = require("cjson")
local parse_query_string, encode_query_string
do
  local _obj_0 = require("lapis.util")
  parse_query_string, encode_query_string = _obj_0.parse_query_string, _obj_0.encode_query_string
end
local SpecServer
do
  local _class_0
  local _base_0 = {
    current_server = nil,
    load_test_server = function(self, overrides)
      local get_free_port
      get_free_port = require("lapis.cmd.util").get_free_port
      local app_port = get_free_port()
      local more_config = {
        port = app_port
      }
      if overrides then
        for k, v in pairs(overrides) do
          more_config[k] = v
        end
      end
      self.current_server = self.runner:attach_server(TEST_ENV, more_config)
      self.current_server.app_port = app_port
      return self.current_server
    end,
    close_test_server = function(self)
      self.runner:detach_server()
      self.current_server = nil
    end,
    get_current_server = function(self)
      return self.current_server
    end,
    request = function(self, path, opts)
      if path == nil then
        path = ""
      end
      if opts == nil then
        opts = { }
      end
      if not (self.current_server) then
        error("The test server is not loaded! (did you forget to load_test_server?)")
      end
      local http = require("socket.http")
      local headers = { }
      local method = opts.method
      local port = opts.port or self.current_server.app_port
      local source
      do
        local data = opts.post or opts.data
        if data then
          if opts.post then
            method = method or "POST"
          end
          if type(data) == "table" then
            headers["Content-type"] = "application/x-www-form-urlencoded"
            data = encode_query_string(data)
          end
          headers["Content-length"] = #data
          source = ltn12.source.string(data)
        end
      end
      local url_host, url_path = path:match("^https?://([^/]+)(.*)$")
      if url_host then
        headers.Host = url_host
        path = url_path
        do
          local override_port = url_host:match(":(%d+)$")
          if override_port then
            port = override_port
          end
        end
      end
      path = path:gsub("^/", "")
      if opts.get then
        local _, url_query = path:match("^(.-)%?(.*)$")
        local get_params
        if url_query then
          get_params = parse_query_string(url_query)
        else
          get_params = { }
        end
        for k, v in pairs(opts.get) do
          get_params[k] = v
        end
        path = path:gsub("^.-(%?.*)$", "") .. "?" .. encode_query_string(get_params)
      end
      if opts.headers then
        for k, v in pairs(opts.headers) do
          headers[k] = v
        end
      end
      local buffer = { }
      local res, status
      res, status, headers = http.request({
        url = "http://127.0.0.1:" .. tostring(port) .. "/" .. tostring(path),
        redirect = false,
        sink = ltn12.sink.table(buffer),
        headers = headers,
        method = method,
        source = source
      })
      assert(res, status)
      local body = table.concat(buffer)
      headers = normalize_headers(headers)
      do
        local error_blob = headers.x_lapis_error
        if error_blob then
          json = require("cjson")
          local summary, err, trace
          do
            local _obj_0 = json.decode(error_blob)
            summary, err, trace = _obj_0.summary, _obj_0.err, _obj_0.trace
          end
          error("\n" .. tostring(summary) .. "\n" .. tostring(err) .. "\n" .. tostring(trace))
        end
      end
      if opts.expect == "json" then
        json = require("cjson")
        if not (pcall(function()
          body = json.decode(body)
        end)) then
          error("expected to get json from " .. tostring(path))
        end
      end
      return status, body, headers
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, runner)
      self.runner = runner
      if not (self.runner) then
        local command_runner
        command_runner = require("lapis.cmd.actions").command_runner
        local _exp_0 = command_runner:get_server_type()
        if "cqueues" == _exp_0 then
          self.runner = require("lapis.cmd.cqueues").runner
        else
          self.runner = require("lapis.cmd.nginx").nginx_runner
        end
      end
    end,
    __base = _base_0,
    __name = "SpecServer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  SpecServer = _class_0
end
local default_server = SpecServer()
return {
  SpecServer = SpecServer,
  load_test_server = (function()
    local _base_0 = default_server
    local _fn_0 = _base_0.load_test_server
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  close_test_server = (function()
    local _base_0 = default_server
    local _fn_0 = _base_0.close_test_server
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  get_current_server = (function()
    local _base_0 = default_server
    local _fn_0 = _base_0.get_current_server
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  request = (function()
    local _base_0 = default_server
    local _fn_0 = _base_0.request
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)()
}
