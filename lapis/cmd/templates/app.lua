return [[lapis = require "lapis"

class extends lapis.Application
  "/": =>
    "Welcome to Lapis #{require "lapis.version"}!"
]]
