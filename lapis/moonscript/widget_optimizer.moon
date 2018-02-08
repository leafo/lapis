import types from require "tableshape"

TAGS = {
  "span"
  "text"
  "raw"
}

optimized = 0

s = (t) ->
  types.shape t, open: true

ref = (name) ->
  types.shape {
    "ref"
    name
    [-1]: types.number + types.nil
  }

requiret = (val) ->
  s {
    "chain"
    ref "require"
    s {
      "call"
      s { val }
    }
  }

str = (text) ->
  types.shape {
    "string"
    types.string
    text
    [-1]: types.number + types.nil
  }

classt = (opts={}) ->
  s {
    "class"
    opts.name or types.string\tag "name"
    opts.parent or types.any\tag "parent"
    opts.body or types.any\tag "body"
  }

class_methodt = (opts={})->
  s {
    "props"
    s {
      s {
        "key_literal"
        opts.name or types.string\tag "name"
      }
      s {
        "fndef"
        types.any
        types.any
        "fat"
        opts.body or types.any\tag "body"
      }
    }
  }

local basic_type

basic_table = s {
  "table"
  types.array_of types.shape {
    types.shape {"key_literal", types.string}
    types.custom (v) -> basic_type v
  }
}

basic_type = str(types.string) + basic_table

-- a static html node that can be pre-compiled
static_html = s {
  "chain"
  ref types.one_of TAGS
  s {
    "call"
    types.array_of basic_type
  }
  [-1]: types.number + types.nil
}

write_to_buffer = (str, loc) ->
  -- @_buffer\write str
  lua_str = "%q"\format(str)\sub 2, -2

  {
    "chain"
    {"self", "_buffer"}
    {"colon", "write"}
    {"call", {
      {"string", '"', lua_str, [-1]: loc}
    }}
    [-1]: loc
  }

compile_static_code = (tree) ->
  optimized += 1
  compile = require("moonscript.compile")
  code = assert compile.tree {
    tree
  }

  import render_html from require "lapis.html"
  fn = loadstring code
  write_to_buffer render_html(fn)

widget = classt {
  parent: requiret str types.one_of {
    "widgets.base"
    "widgets.page"
  }

  body: types.array_of types.one_of {
    class_methodt {
      body: types.array_of types.one_of {
        static_html / compile_static_code
        types.any
      }
    }
    types.any
  }
}

statements = types.array_of widget + types.any

(tree) ->
  out = assert statements\transform tree
  -- print "-- optimized: #{optimized}"
  out


