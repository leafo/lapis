
import types, BaseType from require "tableshape"

loadstring = loadstring or load

deep_copy = (a) ->
  return a unless type(a) == "table"
  with out = {}
    for k,v in pairs a
      out[k] = deep_copy v

TAGS = {
  "applet", "capture", "element", "html_5", "nobr", "quote", "raw", "text", "widget", 'a', 'abbr', 'acronym', 'address', 'area', 'article', 'aside', 'audio', 'b', 'base', 'bdo', 'big', 'blockquote', 'body', 'br', 'button', 'canvas', 'caption', 'center', 'cite', 'code', 'col', 'colgroup', 'command', 'datalist', 'dd', 'del', 'details', 'dfn', 'dialog', 'div', 'dl', 'dt', 'em', 'embed', 'fieldset', 'figure', 'footer', 'form', 'frame', 'frameset', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hgroup', 'hr', 'html', 'i', 'iframe', 'img', 'input', 'ins', 'kbd', 'keygen', 'label', 'legend', 'li', 'link', 'map', 'mark', 'meta', 'meter', 'nav', 'noframes', 'noscript', 'object', 'ol', 'optgroup', 'option', 'p', 'param', 'pre', 'progress', 'q', 'rp', 'rt', 'ruby', 's', 'samp', 'script', 'section', 'select', 'small', 'source', 'span', 'strike', 'strong', 'style', 'sub', 'sup', 'svg', 'table', 'tbody', 'td', 'textarea', 'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'tt', 'u', 'ul', 'var', 'video',
}

class Proxy extends BaseType
  new: (@fn) =>
  check_value: (...) => @.fn!\check_value ...
  _transform: (...) => @.fn!\_transform ...
  describe: => @.fn!\describe!

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

local basic_type, static_html_statement, optimized_statements

basic_table = s {
  "table"
  types.array_of types.shape {
    types.shape {"key_literal", types.string}
    Proxy -> basic_type
  }
}

basic_function = types.shape {
  "fndef"
  types.shape {}
  types.shape {}
  "slim"
  types.array_of Proxy -> static_html_statement
  [-1]: types.number + types.nil
}

basic_type = str(types.string) + basic_table + basic_function

-- a static html node that can be pre-compiled
static_html_statement = s {
  "chain"
  ref types.one_of TAGS
  s {
    "call"
    types.array_of basic_type
  }
  [-1]: types.number + types.nil
}

nested_block_statement = types.one_of {
  types.shape {
    "chain"
    ref types.one_of TAGS
    s {
      "call"
      types.array_of types.one_of {
        s {
          "fndef"
          types.shape {}
          types.shape {}
          "slim"
          Proxy -> optimized_statements
        }
        types.any
      }
    }
    [-1]: types.number + types.nil
  }

  types.shape {
    types.one_of { "if", "unless" }
    types.any
    Proxy -> optimized_statements
    [-1]: types.number + types.nil
  }, extra_fields: types.map_of(
    types.number * types.custom (v) -> v > 3
    types.one_of {
      types.shape {
        "elseif"
        types.any
        Proxy -> optimized_statements
      }

      types.shape {
        "else"
        Proxy -> optimized_statements
      }

      types.any
    }
  )

  types.shape {
    types.one_of {"for", "foreach"}
    types.any
    types.any
    Proxy -> optimized_statements
    [-1]: types.number + types.nil
  }
}

escape_quotes = do
  import P, Cs from require "lpeg"
  pat = Cs (P[[\"]] + P'"' / [[\"]] + 1)^0
  (str) -> (assert pat\match str)

write_to_buffer = (str, loc) ->
  -- @_buffer\write str
  {
    "chain"
    {"self", "_buffer"}
    {"colon", "write"}
    {"call", {
      {"string", '"', escape_quotes(str), [-1]: loc}
    }}
    [-1]: loc
  }

compile_static_code = (tree) ->
  optimized += 1
  compile = require("moonscript.compile")

  code = assert compile.tree {
    deep_copy tree
  }

  import render_html from require "lapis.html"
  fn = loadstring code
  write_to_buffer render_html(fn)

optimized_statements = types.array_of types.one_of {
  static_html_statement / compile_static_code
  nested_block_statement

  types.any
}

widget = classt {
  parent: types.one_of {
    ref types.one_of { "Layout", "Widget" }
    requiret str types.one_of {
      "widgets.base"
      "widgets.page"
    }
  }

  body: types.array_of types.one_of {
    class_methodt {
      body: optimized_statements
    }
    types.any
  }
}

statements = types.array_of widget + types.any

(tree) ->
  assert statements\transform tree

