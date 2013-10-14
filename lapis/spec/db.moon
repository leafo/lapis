
db = require "lapis.db"

truncate_tables = (...) ->
  tables = for t in *{...}
    if type(t) == "table"
      t\table_name!
    else
      t

  db.truncate unpack tables

{
  :truncate_tables
}
