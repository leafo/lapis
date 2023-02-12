-- SQLite models necessary for core model specs

import Model, enum from require "lapis.db.sqlite.model"
import types, create_table from require "lapis.db.sqlite.schema"
import drop_tables, truncate_tables from require "lapis.spec.db"

class Users extends Model
  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"id", types.integer}
      {"name", types.text}
      "PRIMARY KEY (id)"
    }

  @truncate: =>
    truncate_tables @

class Posts extends Model
  @timestamp: true

  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"id", types.integer}
      {"user_id", types.integer null: true}
      {"title", types.text null: false}
      {"body", types.text null: false}
      {"created_at", types.text}
      {"updated_at", types.text}
      "PRIMARY KEY (id)"
    }

  @truncate: =>
    truncate_tables @

class Likes extends Model
  @primary_key: {"user_id", "post_id"}
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"post", belongs_to: "Posts"}
  }

  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"user_id", types.integer}
      {"post_id", types.integer}
      {"count", types.integer default: 0}
      {"created_at", types.text}
      {"updated_at", types.text}

      "PRIMARY KEY (user_id, post_id)"
    }

  @truncate: =>
    truncate_tables @

{:Users, :Posts, :Likes}
