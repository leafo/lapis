
db = require "lapis.db"

class Paginator
  new: (@model, clause, ...) =>
    if type(clause) == "table"
      opts = clause
      clause = ""

    param_count = select "#", ...

    opts = if param_count > 0
      last = select param_count, ...
      type(last) == "table" and last

    @per_page = @model.per_page
    @per_page = opts.per_page if opts
    @prepare_results = opts.prepare_results if opts and opts.prepare_results

    @_clause = db.interpolate_query clause, ...
    @opts = opts

class OffsetPaginator extends Paginator
  per_page: 10

  each_page: (starting_page=1)=>
    coroutine.wrap ->
      page = starting_page
      while true
        results = @get_page page
        break unless next results
        coroutine.yield results, page
        page += 1


  get_all: =>
    @.prepare_results @model\select @_clause, @opts

  -- 1 indexed page
  get_page: (page) =>
    page = (math.max 1, tonumber(page) or 0) - 1
    @.prepare_results @model\select @_clause .. [[
      limit ?
      offset ?
    ]], @per_page, @per_page * page, @opts

  num_pages: =>
    math.ceil @total_items! / @per_page

  total_items: =>
    @_count or= @model\count db.parse_clause(@_clause).where
    @_count

  prepare_results: (...) -> ...

{ :OffsetPaginator, :Paginator }
