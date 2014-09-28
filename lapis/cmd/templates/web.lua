return [[lapis = require "lapis"

lapis.serve class extends lapis.Application
  "/": =>
    "Welcome to Lapis #{require "lapis.version"}!"
]]
