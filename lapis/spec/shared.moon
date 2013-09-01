-- shared memory interface in Lua

-- get
-- get_stale
-- set
-- safe_set
-- add
-- safe_add
-- replace
-- incr
-- delete
-- flush_all
-- flush_expired
class Dict
  new: =>
    @flush_all!

  get: (key) =>
    @store[key], @flags[key]

  set: (key, value, exp, flags) =>
    @store[key] = value
    @flags[key] = flags
    true

  add: (key, ...) =>
    if @store[key] == nil
      @set key, ...
    true

  replace: (key, ...) =>
    if @store[key] != nil
      @set key, ...
    true

  delete: (key) =>
    @set key, nil

  incr: (key, value) =>
    if @store[key] == nil
      return nil, "not found"

    new_val = @store[key] + value
    @store[key] = new_val
    new_val

  get_keys: =>
    [k for k in pairs @store]

  flush_all: =>
    @store = {}
    @flags = {}

make_shared = ->
  setmetatable {}, __index: (key) =>
    with d = Dict!
      @[key] = d

setup = ->
  stack = require "lapis.spec.stack"
  stack.push {
    shared: make_shared!
  }

teardown = ->
  stack = require "lapis.spec.stack"
  stack.pop!

{ :setup, :teardown, :make_shared }
