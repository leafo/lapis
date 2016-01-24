
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


describe "lapis.cmd.actions.execute", ->
  import join, shell_escape from require "lapis.cmd.path"
  local cmd
  local old_dir, new_dir
  lfs = require "lfs"

  before_each ->
    cmd = require "lapis.cmd.actions"
    -- replace the annotated path with silent one
    cmd.set_path require "lapis.cmd.path"

    old_dir = lfs.currentdir!
    new_dir = join old_dir, "spec_tmp_app"
    assert lfs.mkdir new_dir
    assert lfs.chdir new_dir

  after_each ->
    assert lfs.chdir old_dir
    os.execute "rm -r '#{shell_escape new_dir}'"

  list_files = (dir, accum={}, prefix="") ->
    for f in lfs.dir dir
      continue if f\match "^%.*$"
      relative_name = join prefix, f
      if "directory" == lfs.attributes relative_name, "mode"
        list_files join(dir, f), accum, relative_name
      else
        table.insert accum, relative_name

    accum

  assert_files = (files) ->
    have_files = list_files lfs.currentdir!
    table.sort files
    table.sort have_files
    assert.same files, have_files

  describe "new", ->
    it "default app", ->
      cmd.execute { [0]: "lapis", "new" }

      assert_files {
        "app.moon", "mime.types", "models.moon", "nginx.conf"
      }

    it "etlua config", ->
      cmd.execute { [0]: "lapis", "new", "--etlua-config" }

      assert_files {
        "app.moon", "mime.types", "models.moon", "nginx.conf.etlua"
      }

    it "command line flags can go anywhere", ->
      cmd.execute { [0]: "lapis", "--etlua-config", "new" }

      assert_files {
        "app.moon", "mime.types", "models.moon", "nginx.conf.etlua"
      }

    it "lua default", ->
      cmd.execute { [0]: "lapis", "new", "--lua" }
      assert_files {
        "app.lua", "mime.types", "models.lua", "nginx.conf"
      }

    it "has tup", ->
      cmd.execute { [0]: "lapis", "new", "--tup" }
      assert_files {
        "app.moon", "mime.types", "models.moon", "nginx.conf", "Tupfile", "Tuprules.tup"
      }

    it "has git", ->
      cmd.execute { [0]: "lapis", "new", "--git" }
      assert_files {
        "app.moon", "mime.types", "models.moon", "nginx.conf", ".gitignore"
      }

  describe "build", ->
    it "buils app", ->
      cmd.execute { [0]: "lapis", "new" }
      cmd.execute { [0]: "lapis", "build" }

      assert_files {
        "app.moon", "mime.types", "models.moon", "nginx.conf", "nginx.conf.compiled"
      }

  describe "generate", ->
    it "generates model", ->
      cmd.execute { [0]: "lapis", "generate", "model", "things" }
      assert_files { "models/things.moon" }

    it "generates spec", ->
      cmd.execute { [0]: "lapis", "generate", "spec", "models.things" }
      assert_files { "spec/models/things_spec.moon" }


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


