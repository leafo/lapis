lapis = require "lapis"
db = require "lapis.db"

class extends lapis.Application
  "/": =>
    json: db.query "show tables like ?", "users"
