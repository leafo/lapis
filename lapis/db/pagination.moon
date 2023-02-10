
import insert, concat from table
import get_fields from require "lapis.util"

unpack = unpack or table.unpack

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


flatten_iter = (iter) ->
  current_page = iter!
  idx = 1
  ->
    if current_page
      with current_page[idx]
        idx += 1
        unless current_page[idx]
          current_page = iter!
          idx = 1

class Paginator
  new: (@model, clause="", ...) =>
    @db = @model.__class.db
    param_count = select "#", ...

    if @db.is_clause clause
      clause = @db.interpolate_query "WHERE ?", clause

    opts = if param_count > 0
      last = select param_count, ...
      if type(last) == "table" and not @db.is_encodable last
        param_count -= 1
        last
    elseif type(clause) == "table"
      opts = clause
      clause = ""
      opts

    @per_page = @model.per_page
    @per_page = opts.per_page if opts

    @_clause = if param_count > 0
      @db.interpolate_query clause, ...
    else
      clause

    @opts = opts

  select: (...) =>
    @model\select ...

  prepare_results: (items) =>
    if pr = @opts and @opts.prepare_results
      pr items
    else
      items

  each_item: =>
    flatten_iter @each_page!

class OffsetPaginator extends Paginator
  per_page: 10

  each_page: (page=1) =>
    ->
      results = @get_page page
      if next results
        page += 1
        results

  get_all: =>
    @prepare_results @select @_clause, @opts

  -- 1 indexed page
  get_page: (page) =>
    page = (math.max 1, tonumber(page) or 0) - 1
    limit = @db.interpolate_query " LIMIT ? OFFSET ?",
      @per_page, @per_page * page, @opts

    @prepare_results @select @_clause .. limit, @opts

  num_pages: =>
    math.ceil @total_items! / @per_page

  has_items: =>
    tbl_name = @db.escape_identifier @model\table_name!

    res = if @db.parse_clause
      parsed = @db.parse_clause(@_clause)
      parsed.limit = "1"
      parsed.offset = nil
      parsed.order = nil

      @db.query "SELECT 1 FROM #{tbl_name} #{rebuild_query_clause parsed}"
    else
      -- don't have clause parser available, fallback to assuming clause is simple where statement
      @db.select "1 FROM #{tbl_name} #{@_clause} LIMIT 1"

    not not unpack res

  total_items: =>
    unless @_count
      tbl_name = @db.escape_identifier @model\table_name!

      if @db.parse_clause
        parsed = @db.parse_clause(@_clause)

        parsed.limit = nil
        parsed.offset = nil
        parsed.order = nil

        if parsed.group
          error "OffsetPaginator: can't calculate total items in a query with group by"

        query = "COUNT(*) AS c FROM #{tbl_name} #{rebuild_query_clause parsed}"
        @_count = unpack(@db.select query).c
      else
        -- don't have clause parser available, fallback to assuming clause is simple where statement
        query = "COUNT(*) AS c FROM #{tbl_name} #{@_clause}"
        @_count = unpack(@db.select query).c

    @_count

class OrderedPaginator extends Paginator
  order: "ASC" -- default sort order
  per_page: 10

  valid_orders = {
    asc: true
    desc: true
  }

  new: (model, @field, ...) =>
    super model, ...

    if @opts and @opts.order
      @order = @opts.order
      @opts.order = nil

  each_page: =>
    tuple = {}

    ->
      tuple = { @get_page unpack tuple, 2 }
      if next tuple[1]
        tuple[1]

  get_page: (...) =>
    @get_ordered @order, ...

  after: (...) =>
    @get_ordered "ASC", ...

  before: (...) =>
    @get_ordered "DESC", ...

  get_ordered: (order, ...) =>
    parsed = assert @db.parse_clause @_clause
    has_multi_fields = type(@field) == "table" and not @db.is_raw @field

    order_lower = order\lower!
    unless valid_orders[order_lower]
      error "OrderedPaginator: invalid query order: #{order}"

    table_name = @model\table_name!
    prefix = @db.escape_identifier(table_name) .. "."

    escaped_fields = if has_multi_fields
      [prefix .. @db.escape_identifier f for f in *@field]
    else
      { prefix .. @db.escape_identifier @field }

    if parsed.order
      error "OrderedPaginator: order should not be provided for #{@@__name}"

    if parsed.offset or parsed.limit
      error "OrderedPaginator: offset and limit should not be provided for #{@@__name}"

    parsed.order = table.concat ["#{f} #{order}" for f in *escaped_fields], ", "

    if ...
      op = switch order\lower!
        when "asc"
          ">"
        when "desc"
          "<"

      pos_count = select "#", ...
      if pos_count > #escaped_fields
        error "OrderedPaginator: passed in too many values for paginated query (expected #{#escaped_fields}, got #{pos_count})"

      order_clause = if 1 == pos_count
        order_clause = "#{escaped_fields[1]} #{op} #{@db.escape_literal (...)}"
      else
        positions = {...}
        buffer = {"("}

        for i in ipairs positions
          unless escaped_fields[i]
            error "passed in too many values for paginated query (expected #{#escaped_fields}, got #{pos_count})"

          insert buffer, escaped_fields[i]
          insert buffer, ", "

        buffer[#buffer] = nil

        insert buffer, ") "
        insert buffer, op
        insert buffer, " ("

        for pos in *positions
          insert buffer, @db.escape_literal pos
          insert buffer, ", "

        buffer[#buffer] = nil
        insert buffer, ")"
        concat buffer

      if parsed.where
        parsed.where = "#{order_clause} and (#{parsed.where})"
      else
        parsed.where = order_clause

    parsed.limit = tostring @per_page
    query = rebuild_query_clause parsed

    res = @select query, @opts

    final = res[#res]
    res = @prepare_results res

    if has_multi_fields
      res, get_fields final, unpack @field
    else
      res, get_fields final, @field

{ :OffsetPaginator, :OrderedPaginator, :Paginator}
