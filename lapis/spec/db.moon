
db = require "lapis.db"

truncate_tables = (...) ->
  tables = for t in *{...}
    if type(t) == "table"
      t\table_name!
    else
      t

  for table in *tables
    db.delete table

  -- truncate is slow, so delete is used instead
  -- db.truncate unpack tables

{
  :truncate_tables
}
