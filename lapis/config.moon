
import insert from table

local *

scope_meta = {
  __index: do
    set = (k, v) =>
      if type(k) == "table"
        for sub_k, sub_v in pairs k
          merge_set @_conf, sub_k, sub_v
      else
        if type(v) == "function"
          @_conf[k] = run_with_scope v, {}
        else
          merge_set @_conf, k, v

    (name) =>
      val = _G[name]
      return val unless val == nil

      with val = switch name
          when "set"
            (...) -> set @, ...
          when "unset"
            (...) ->
              for k in *{...}
                @_conf[k] = nil
          when "include"
            (fn) -> run_with_scope fn, @_conf
          else
            (v) -> set @, name, v

        @[name] = val
}

configs = {}
config = (environment, fn) ->
  configs[environment] or= {}
  table.insert configs[environment], fn
  nil

run_with_scope = (fn, conf) ->
  old_env = getfenv fn
  env = setmetatable { _conf: conf }, scope_meta
  setfenv fn, env
  fn!
  setfenv fn, old_env
  conf

merge_set = (t, k, v) ->
  existing = t[k]
  if existing and type(existing) == "table" and type(v) == "table"
    for sub_k, sub_v in pairs v
      merge_set existing, sub_k, sub_v
  else
    t[k] = v

for_environment = do
  cache = {}
  (name) ->
    return cache[name] if cache[name]
    conf = if fns = configs[name]
      with c = {}
        for fn in *fns
          run_with_scope fn, c
    else
      {}

    cache[name] = conf
    conf


if ... == "test"
  require "moon"

  f = ->
    burly "dad"
    color "blue"

  config "basic", ->
    print "hello world"
    color "red"
    port 80

    things ->
      cool "yes"
      yes "really"

    include ->
      height "10px"

    set "not", "yeah"

    set many: "things", are: "set"

    include f

  conf = for_environment "basic"
  moon.p conf

  print!
  x = {}

  config "cool", ->
    hello {
      one: "thing"
      leads: "another"
      nest: {
        egg: true
        grass: true
      }
    }

    hello {
       dad: "son"
       nest: {
         bird: false
         grass: false
       }
    }

  moon.p for_environment "cool"

{ :config, :for_environment, :merge_set }

