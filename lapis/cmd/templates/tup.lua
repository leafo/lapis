return {
  ["Tuprules.tup"] = [[: foreach *.moon |> moonc %f |> %B.lua
]],
  ["Tupfile"] = [[include_rules
]]
}
