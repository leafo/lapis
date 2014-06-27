
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


