
make_super = (cls) ->
  (method, ...) =>
    fn = if method == "new"
      cls.__parent.__init
    else
      cls.__parent.__base[method]

    fn @, ...

-- _class "Hello", {
--   print_name: => print "hello!"
-- }, AnotherClass
_class = (name, tbl, extend, setup_fn) ->
  cls = if extend
    class extends extend
      new: tbl and tbl.new

      @__base.super = make_super @__class
      @__name: name

      if tbl
        tbl.new = nil
        for k,v in pairs tbl
          @__base[k] = v

      setup_fn and setup_fn @
  else
    class
      new: tbl and tbl.new

      @__base.super = make_super @__class
      @__name: name

      if tbl
        tbl.new = nil
        for k,v in pairs tbl
          @__base[k] = v

      setup_fn and setup_fn @

  cls

{ class: _class }
