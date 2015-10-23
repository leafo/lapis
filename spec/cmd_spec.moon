
nginx = require "lapis.cmd.nginx"

describe "lapis.cmd.nginx", ->
  it "should compile config", ->
    tpl = [[
hello: ${{some_var}}]]

    compiled = nginx.compile_config tpl, { some_var: "what's up" }

    assert.same [[
env LAPIS_ENVIRONMENT;
hello: what's up]], compiled

  it "should compile postgres connect string", ->
    tpl = [[
pg-connect: ${{pg postgres}}]]
    compiled = nginx.compile_config tpl, {
      postgres: "postgres://pg_user:user_password@127.0.0.1/my_database"
    }

    assert.same [[
env LAPIS_ENVIRONMENT;
pg-connect: 127.0.0.1 dbname=my_database user=pg_user password=user_password]], compiled


  it "should compile postgres connect table", ->
    tpl = [[
pg-connect: ${{pg postgres}}]]
    compiled = nginx.compile_config tpl, {
      postgres: {
        host: "example.com:1234"
        user: "leafo"
        password: "thepass"
        database: "hello"
      }
    }

    assert.same [[
env LAPIS_ENVIRONMENT;
pg-connect: example.com:1234 dbname=hello user=leafo password=thepass]], compiled

  it "should read environment variable", ->
    unless pcall -> require "posix"
      pending "lposix is required for cmd.nginx specs"
      return

    posix = require "posix"
    val = "hi there #{os.time!}"
    posix.setenv "LAPIS_COOL", val

    compiled = nginx.compile_config "thing: ${{cool}}"
    assert.same "env LAPIS_ENVIRONMENT;\nthing: #{val}", compiled

  it "should compile etlua config", ->
    tpl = [[
hello: <%- some_var %>]]

    compiled = nginx.compile_etlua_config tpl, { some_var: "what's up" }

    assert.same [[
env LAPIS_ENVIRONMENT;
hello: what's up]], compiled

  it "should read environment variable in etlua config", ->
    unless pcall -> require "posix"
      pending "lposix is required for cmd.nginx specs"
      return

    posix = require "posix"
    val = "hi there #{os.time!}"
    posix.setenv "LAPIS_COOL", val

    compiled = nginx.compile_etlua_config "thing: <%- cool %>"
    assert.same "env LAPIS_ENVIRONMENT;\nthing: #{val}", compiled

describe "lapis.cmd.actions", ->
  import get_action, execute from require "lapis.cmd.actions"

  it "gets built in action", ->
    action = get_action "help"
    assert.same "help", action.name

  it "gets nil for invalid action", ->
    action = get_action "wazzupf2323"
    assert.same nil, action

  it "gets action from module", ->
    package.loaded["lapis.cmd.actions.cool"] = {
      name: "cool"
      ->
    }

    action = get_action "cool"
    assert.same "cool", action.name

  it "executes help", ->
    p = _G.print
    _G.print = ->
    execute {"help"}
    _G.print = p

describe "lapis.cmd.util", ->
  it "columnizes", ->
    import columnize from require "lapis.cmd.util"

    columnize {
      {"hello", "here is some info"}
      {"what is going on", "this is going to be a lot of text so it wraps around the end"}
      {"this is something", "not so much here"}
      {"else", "yeah yeah yeah not so much okay goodbye"}
    }

  it "parses flags", ->
    import parse_flags from require "lapis.cmd.util"
    flags, args = parse_flags { "hello", "--world", "-h=1", "yeah" }

    assert.same {
      h: "1"
      world: true
    }, flags

    assert.same {
      "hello"
      "yeah"
    }, args

    flags, args = parse_flags { "new", "dad" }
    assert.same {}, flags
    assert.same {
      "new"
      "dad"
    }, args


