db = require "lapis.db"

assert_model = (primary_model, source) ->
  -- TODO: the primary model may influcence how related models are loaded
  models = require "models"
  with m = models[source]
    error "failed to find model `#{source}` for relationship" unless m

fetch = (name, opts) =>
  source = opts.fetch
  assert type(source) == "function", "Expecting function for `fetch` relation"

  get_method = opts.as or "get_#{name}"

  @__base[get_method] = =>
    existing = @[name]
    return existing if existing != nil
    with obj = source @
      @[name] = obj

belongs_to = (name, opts) =>
  source = opts.belongs_to
  assert type(source) == "string", "Expecting model name for `belongs_to` relation"

  get_method = opts.as or "get_#{name}"
  column_name = "#{name}_id"

  @__base[get_method] = =>
    return nil unless @[column_name]
    existing = @[name]
    return existing if existing != nil
    model = assert_model @__class, source
    with obj = model\find @[column_name]
      @[name] = obj

has_one = (name, opts) =>
  source = opts.has_one
  assert type(source) == "string", "Expecting model name for `has_one` relation"

  get_method = opts.as or "get_#{name}"

  @__base[get_method] = =>
    existing = @[name]
    return existing if existing != nil
    model = assert_model @__class, source

    foreign_key = opts.key or "#{@@singular_name!}_id"

    clause = {
      [foreign_key]: @[@@primary_keys!]
    }

    with obj = model\find clause
      @[name] = obj

has_many = (name, opts) =>
  if opts.pager == false
    error "not yet"

  source = opts.has_many
  assert type(source) == "string", "Expecting model name for `has_many` relation"

  get_method = opts.as or "get_#{name}"

  @__base[get_method] = (fetch_opts) =>
    model = assert_model @__class, source

    foreign_key = opts.key or "#{@@singular_name!}_id"

    clause = {
      [foreign_key]: @[@@primary_keys!]
    }

    if where = opts.where
      for k,v in pairs where
        clause[k] = v

    clause = db.encode_clause clause

    model\paginated "where #{clause}", fetch_opts


{ :fetch, :belongs_to, :has_one, :has_many }
