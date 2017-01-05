[[
-- config.moon
config = require "lapis.config"

config { "development", "production" }, ->
  app_name "My New Lapis App"

config "production", ->
  port 80

config "testing", ->
  port 8080

config "development", ->
  port 8080
]]