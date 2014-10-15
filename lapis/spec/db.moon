
db = require "lapis.db"
import assert_env from require "lapis.environment"

truncate_tables = (...) ->
  assert_env "test", for: "truncate_tables"

  tables = for t in *{...}
    if type(t) == "table"
      t\table_name!
    else
      t

  -- truncate is slow, so delete is used instead
  -- db.truncate unpack tables
  for table in *tables
    db.delete table

{
  :truncate_tables
}
