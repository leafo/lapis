
describe "lapis.lua", ->
  it "works with super", ->
    lua = require "lapis.lua"
    local *

    Base = lua.class "Base", {
      new: => print "yeah"
    }

    LuaClass = lua.class "LuaClass", {
      new: =>
        print "hello!"
        LuaClass\super @, "new"

    }, Base

    LuaClass2 = lua.class "LuaClass2", {
    }, LuaClass

    LuaClass2!

