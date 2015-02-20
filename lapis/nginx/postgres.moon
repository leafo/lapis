io.stderr\write "WARNING: The module `lapis.nginx.postgres` has moved to `lapis.db.postgres`
  Please update your require statements as the old path will no longer be
  available in future versions of lapis.\n\n"

require "lapis.db.postgres"

