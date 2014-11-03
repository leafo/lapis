
local *

_class = (name, tbl, extend) ->
  unless type(name) == "string"
    extend = tbl
    tbl = name
    name = nil

  cls = if extend
    class extends extend
      new: tbl and tbl.new
  else
    class
      new: tbl and tbl.new

  base = cls.__base

  if tbl
    tbl.new = nil
    for k,v in pairs tbl
      base[k] = v

  base.super or= _super

  cls.__name = name

  if inherited = extend and extend.__inherited
    inherited extend, cls

  cls

_super = (instance, method, ...) ->
  parent_method = if method == "new"
    instance.__class.__parent.__init
  else
    instance.__class.__parent.__base[method]

  parent_method instance, ...

{ class: _class, super: _super }
