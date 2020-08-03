import Model, enum from require "lapis.db.mysql.model"
import types, create_table from require "lapis.db.mysql.schema"
import drop_tables, truncate_tables from require "lapis.spec.db"

class Users extends Model
  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"id", types.id}
      {"name", types.text}
    }

  @truncate: =>
    truncate_tables @

class Posts extends Model
  @timestamp: true

  @relations: {
    {"images", has_many: "Images"}
  }

  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"id", types.id}
      {"user_id", types.integer null: true}
      {"title", types.text null: true}
      {"body", types.text null: true}
      {"created_at", types.datetime}
      {"updated_at", types.datetime}
    }

  @truncate: =>
    truncate_tables @

class Images extends Model
  @primary_key: {"user_id", "id"}
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"post", belongs_to: "Posts"}
  }

  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"post_id", types.integer}
      -- Can't use types.id for "id" because it specifies primary_key
      {"id", types.integer auto_increment: true}
      {"user_id", types.integer null: true}
      {"url", types.text null: false}
      {"created_at", types.datetime}
      {"updated_at", types.datetime}

      "PRIMARY KEY (post_id, id)"
      -- auto_increment must be a key of its own (PK or otherwise)
      "KEY id (id)"
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
      {"created_at", types.datetime}
      {"updated_at", types.datetime}

      "PRIMARY KEY (user_id, post_id)"
    }

  @truncate: =>
    truncate_tables @

{:Users, :Posts, :Images, :Likes}
