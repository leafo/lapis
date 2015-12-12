
describe "lapis.lua", ->
  it "works with super", ->
    lua = require "lapis.lua"
    count = 0

    local *

    Base = lua.class "Base", {
      new: =>
        count += 2
    }

    LuaClass = lua.class "LuaClass", {
      new: =>
        count += 3
        LuaClass\super @, "new"

    }, Base

    LuaClass2 = lua.class "LuaClass2", {
    }, LuaClass

    LuaClass2!

    assert.same 5, count


