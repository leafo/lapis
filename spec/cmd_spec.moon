
nginx = require "lapis.cmd.nginx"

describe "lapis.cmd.nginx", ->
  it "should compile config", ->
    tpl = [[
      hello: ${{some_var}}
    ]]
    input = nginx.compile_config tpl, { some_var: "what's up" }

    assert.same input, [[
      hello: what's up
    ]]

  it "should read environment variable", ->
    return pending "need lposix for test" unless pcall -> require "posix"

    posix = require "posix"
    val = "hi there #{os.time!}"
    posix.setenv "LAPIS_COOL", val

    input = nginx.compile_config "thing: ${{cool}}"
    assert.same input, "thing: #{val}"


