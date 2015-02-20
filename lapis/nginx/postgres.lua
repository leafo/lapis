io.stderr:write("WARNING: The module `lapis.nginx.postgres` has moved to `lapis.db.postgres`\n  Please update your require statements as the old path will no longer be\n  available in future versions of lapis.\n\n")
return require("lapis.db.postgres")
