
db = require "lapis.db"

import insert, concat from table

query_parts = {"where", "group", "having", "order", "limit", "offset"}
rebuild_query_clause = (parsed) ->
  buffer = {}

  if joins = parsed.join
    for {join_type, join_clause} in *joins
      insert buffer, join_type
      insert buffer, join_clause

  for p in *query_parts
    clause = parsed[p]
    continue unless clause and clause != ""

    p = "order by" if p == "order"
    p = "group by" if p == "group"

    insert buffer, p
    insert buffer, clause

  concat buffer, " "

class Paginator
  new: (@model, clause="", ...) =>
    param_count = select "#", ...

    opts = if param_count > 0
      last = select param_count, ...
      type(last) == "table" and last
    elseif type(clause) == "table"
      opts = clause
      clause = ""
      opts

    @per_page = @model.per_page
    @per_page = opts.per_page if opts
    @prepare_results = opts.prepare_results if opts and opts.prepare_results

    @_clause = db.interpolate_query clause, ...
    @opts = opts

class OffsetPaginator extends Paginator
  per_page: 10

  each_page: (starting_page=1) =>
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
    unless @_count
      parsed = db.parse_clause(@_clause)

      parsed.limit = nil
      parsed.offset = nil
      parsed.order = nil

      if parsed.group
        error "Paginator can't calculate total items in a query with group by"

      tbl_name = db.escape_identifier @model\table_name!
      query = "COUNT(*) as c from #{tbl_name} #{rebuild_query_clause parsed}"
      @_count = unpack(db.select query).c

    @_count

  prepare_results: (...) -> ...


class OrderedPaginator extends Paginator
  order: "ASC"
  per_page: 10

  prepare_results: (...) -> ...

  new: (model, @field, ...) =>
    super model, ...

    if @opts and @opts.order
      @order = @opts.order
      @opts.order = nil

  each_page: =>
    coroutine.wrap ->
      local page
      while true
        items, page = @get_page page
        if next items
          coroutine.yield items
        else
          break

  get_page: (prev_pos) =>
    parsed = db.parse_clause @_clause

    field = db.escape_identifier @field

    if parsed.order
      error "order should not be provided for #{@@__name}"

    if parsed.offset or parsed.limit
      error "offset and limit should not be provided for #{@@__name}"

    parsed.order = "#{field} #{@order}"

    if prev_pos
      field_clause = switch @order\lower!
        when "asc"
          "#{field} > #{db.escape_literal prev_pos}"
        when "desc"
          "#{field} < #{db.escape_literal prev_pos}"
        else
          error "don't know how to handle order #{@order}"

      if parsed.where
        parsed.where = "#{field_clause} and (#{parsed.where})"
      else
        parsed.where = field_clause

    parsed.limit = tostring @per_page
    query = rebuild_query_clause parsed

    res = @model\select query, opts
    final = res[#res]
    @.prepare_results(res), final and final[@model.primary_key]


{ :OffsetPaginator, :OrderedPaginator, :Paginator}
