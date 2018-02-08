local types
types = require("tableshape").types
local TAGS = {
  "span",
  "text",
  "raw"
}
local optimized = 0
local s
s = function(t)
  return types.shape(t, {
    open = true
  })
end
local ref
ref = function(name)
  return types.shape({
    "ref",
    name,
    [-1] = types.number + types["nil"]
  })
end
local requiret
requiret = function(val)
  return s({
    "chain",
    ref("require"),
    s({
      "call",
      s({
        val
      })
    })
  })
end
local str
str = function(text)
  return types.shape({
    "string",
    types.string,
    text,
    [-1] = types.number + types["nil"]
  })
end
local classt
classt = function(opts)
  if opts == nil then
    opts = { }
  end
  return s({
    "class",
    opts.name or types.string:tag("name"),
    opts.parent or types.any:tag("parent"),
    opts.body or types.any:tag("body")
  })
end
local class_methodt
class_methodt = function(opts)
  if opts == nil then
    opts = { }
  end
  return s({
    "props",
    s({
      s({
        "key_literal",
        opts.name or types.string:tag("name")
      }),
      s({
        "fndef",
        types.any,
        types.any,
        "fat",
        opts.body or types.any:tag("body")
      })
    })
  })
end
local basic_type
local basic_table = s({
  "table",
  types.array_of(types.shape({
    types.shape({
      "key_literal",
      types.string
    }),
    types.custom(function(v)
      return basic_type(v)
    end)
  }))
})
basic_type = str(types.string) + basic_table
local static_html = s({
  "chain",
  ref(types.one_of(TAGS)),
  s({
    "call",
    types.array_of(basic_type)
  }),
  [-1] = types.number + types["nil"]
})
local write_to_buffer
write_to_buffer = function(str, loc)
  local lua_str = ("%q"):format(str):sub(2, -2)
  return {
    "chain",
    {
      "self",
      "_buffer"
    },
    {
      "colon",
      "write"
    },
    {
      "call",
      {
        {
          "string",
          '"',
          lua_str,
          [-1] = loc
        }
      }
    },
    [-1] = loc
  }
end
local compile_static_code
compile_static_code = function(tree)
  optimized = optimized + 1
  local compile = require("moonscript.compile")
  local code = assert(compile.tree({
    tree
  }))
  local render_html
  render_html = require("lapis.html").render_html
  local fn = loadstring(code)
  return write_to_buffer(render_html(fn))
end
local widget = classt({
  parent = requiret(str(types.one_of({
    "widgets.base",
    "widgets.page"
  }))),
  body = types.array_of(types.one_of({
    class_methodt({
      body = types.array_of(types.one_of({
        static_html / compile_static_code,
        types.any
      }))
    }),
    types.any
  }))
})
local statements = types.array_of(widget + types.any)
return function(tree)
  local out = assert(statements:transform(tree))
  return out
end
