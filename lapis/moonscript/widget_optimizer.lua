local types, BaseType
do
  local _obj_0 = require("tableshape")
  types, BaseType = _obj_0.types, _obj_0.BaseType
end
local loadstring = loadstring or load
local deep_copy
deep_copy = function(a)
  if not (type(a) == "table") then
    return a
  end
  do
    local out = { }
    for k, v in pairs(a) do
      out[k] = deep_copy(v)
    end
    return out
  end
end
local TAGS = {
  "applet",
  "capture",
  "element",
  "html_5",
  "nobr",
  "quote",
  "raw",
  "text",
  "widget",
  'a',
  'abbr',
  'acronym',
  'address',
  'area',
  'article',
  'aside',
  'audio',
  'b',
  'base',
  'bdo',
  'big',
  'blockquote',
  'body',
  'br',
  'button',
  'canvas',
  'caption',
  'center',
  'cite',
  'code',
  'col',
  'colgroup',
  'command',
  'datalist',
  'dd',
  'del',
  'details',
  'dfn',
  'dialog',
  'div',
  'dl',
  'dt',
  'em',
  'embed',
  'fieldset',
  'figure',
  'footer',
  'form',
  'frame',
  'frameset',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'head',
  'header',
  'hgroup',
  'hr',
  'html',
  'i',
  'iframe',
  'img',
  'input',
  'ins',
  'kbd',
  'keygen',
  'label',
  'legend',
  'li',
  'link',
  'map',
  'mark',
  'meta',
  'meter',
  'nav',
  'noframes',
  'noscript',
  'object',
  'ol',
  'optgroup',
  'option',
  'p',
  'param',
  'pre',
  'progress',
  'q',
  'rp',
  'rt',
  'ruby',
  's',
  'samp',
  'script',
  'section',
  'select',
  'small',
  'source',
  'span',
  'strike',
  'strong',
  'style',
  'sub',
  'sup',
  'svg',
  'table',
  'tbody',
  'td',
  'textarea',
  'tfoot',
  'th',
  'thead',
  'time',
  'title',
  'tr',
  'tt',
  'u',
  'ul',
  'var',
  'video'
}
local Proxy
do
  local _class_0
  local _parent_0 = BaseType
  local _base_0 = {
    check_value = function(self, ...)
      return self.fn():check_value(...)
    end,
    _transform = function(self, ...)
      return self.fn():_transform(...)
    end,
    describe = function(self)
      return self.fn():describe()
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, fn)
      self.fn = fn
    end,
    __base = _base_0,
    __name = "Proxy",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Proxy = _class_0
end
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
local basic_type, static_html_statement, optimized_statements
local basic_table = s({
  "table",
  types.array_of(types.shape({
    types.shape({
      "key_literal",
      types.string
    }),
    Proxy(function()
      return basic_type
    end)
  }))
})
local basic_function = types.shape({
  "fndef",
  types.shape({ }),
  types.shape({ }),
  "slim",
  types.array_of(Proxy(function()
    return static_html_statement
  end)),
  [-1] = types.number + types["nil"]
})
basic_type = str(types.string) + basic_table + basic_function
static_html_statement = s({
  "chain",
  ref(types.one_of(TAGS)),
  s({
    "call",
    types.array_of(basic_type)
  }),
  [-1] = types.number + types["nil"]
})
local nested_block_statement = types.one_of({
  types.shape({
    "chain",
    ref(types.one_of(TAGS)),
    s({
      "call",
      types.array_of(types.one_of({
        s({
          "fndef",
          types.shape({ }),
          types.shape({ }),
          "slim",
          Proxy(function()
            return optimized_statements
          end)
        }),
        types.any
      }))
    }),
    [-1] = types.number + types["nil"]
  }),
  types.shape({
    types.one_of({
      "if",
      "unless"
    }),
    types.any,
    Proxy(function()
      return optimized_statements
    end),
    [-1] = types.number + types["nil"]
  }, {
    extra_fields = types.map_of(types.number * types.custom(function(v)
      return v > 3
    end), types.one_of({
      types.shape({
        "elseif",
        types.any,
        Proxy(function()
          return optimized_statements
        end)
      }),
      types.shape({
        "else",
        Proxy(function()
          return optimized_statements
        end)
      }),
      types.any
    }))
  }),
  types.shape({
    types.one_of({
      "for",
      "foreach"
    }),
    types.any,
    types.any,
    Proxy(function()
      return optimized_statements
    end),
    [-1] = types.number + types["nil"]
  })
})
local escape_quotes
do
  local P, Cs
  do
    local _obj_0 = require("lpeg")
    P, Cs = _obj_0.P, _obj_0.Cs
  end
  local pat = Cs((P([[\"]]) + P('"') / [[\"]] + 1) ^ 0)
  escape_quotes = function(str)
    return (assert(pat:match(str)))
  end
end
local write_to_buffer
write_to_buffer = function(str, loc)
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
          escape_quotes(str),
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
    deep_copy(tree)
  }))
  local render_html
  render_html = require("lapis.html").render_html
  local fn = loadstring(code)
  return write_to_buffer(render_html(fn))
end
optimized_statements = types.array_of(types.one_of({
  static_html_statement / compile_static_code,
  nested_block_statement,
  types.any
}))
local widget = classt({
  parent = types.one_of({
    ref(types.one_of({
      "Layout",
      "Widget"
    })),
    requiret(str(types.one_of({
      "widgets.base",
      "widgets.page"
    })))
  }),
  body = types.array_of(types.one_of({
    class_methodt({
      body = optimized_statements
    }),
    types.any
  }))
})
local statements = types.array_of(widget + types.any)
return function(tree)
  return assert(statements:transform(tree))
end
