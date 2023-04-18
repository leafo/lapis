
nginx = require "lapis.cmd.nginx"

describe "lapis.cmd.nginx", ->
  local snapshot

  before_each ->
    snapshot = assert\snapshot!

    stub(os, "exit").invokes (status) ->
      error "os.exit was called unexpectedly: #{exit_code}"

  after_each ->
    snapshot\revert!

  it "should compile config", ->
    tpl = [[
hello: ${{some_var}}]]

    compiled = nginx.compile_config tpl, { some_var: "what's up" }

    assert.same [[
env LAPIS_ENVIRONMENT;
hello: what's up]], compiled

  it "compies config with variable that doesn't exist", ->
    tpl = [[
hello: ${{oops_var}}]]

    compiled = nginx.compile_config tpl, { some_var: "what's up" }

    assert.same [[
env LAPIS_ENVIRONMENT;
hello: ${{oops_var}}]], compiled

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
      pending "luaposix is required for cmd.nginx specs"
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
      pending "luaposix is required for cmd.nginx specs"
      return

    posix = require "posix"
    val = "hi there #{os.time!}"
    posix.setenv "LAPIS_COOL", val

    compiled = nginx.compile_etlua_config "thing: <%- cool %>"
    assert.same "env LAPIS_ENVIRONMENT;\nthing: #{val}", compiled

describe "lapis.cmd.actions", ->
  import get_command, command_runner, execute from require "lapis.cmd.actions"

  it "builds the command parser", ->
    parser = command_runner\build_parser!
    assert.same {false, "a command is required"}, { parser\pparse {} }

  it "gets built in action", ->
    command = get_command "new"
    assert.same "new", command.name

  it "gets nil for invalid action", ->
    command = get_command "wazzupf2323"
    assert.same nil, command

  it "executes help", ->
    local exit_status

    stub(os, "exit").invokes (status) ->
      exit_status = status
      coroutine.yield "os.exit"

    output = {}

    s_print = stub(_G, "print").invokes (...) ->
      table.insert output, table.concat {...}, "\t"

    assert.same "os.exit", coroutine.wrap(-> execute {"help"})!
    print\revert!

    output = table.concat output, "\n"

    assert.same 0, exit_status
    assert output\match "Options:"


describe "lapis.cmd.actions.execute", ->
  import join, shell_escape from require "lapis.cmd.path"
  local cmd
  local old_dir, new_dir, old_package_path
  lfs = require "lfs"

  before_each ->
    cmd = require "lapis.cmd.actions"
    -- replace the annotated path with silent one
    cmd.command_runner.path = require "lapis.cmd.path"

    old_dir = lfs.currentdir!

    old_package_path = package.path
    package.path ..= ";#{old_dir}/?.lua"

    new_dir = join old_dir, "spec_tmp_app"
    assert lfs.mkdir new_dir
    assert lfs.chdir new_dir

  after_each ->
    package.path = old_package_path
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

  describe "debug", ->
    it "gets default environment with no overrides", ->
      res = cmd.execute { "debug" }
      assert.same "test", res.environment

    it "environment with --environment", ->
      res = cmd.execute { "debug", "--environment", "cool" }
      assert.same "cool", res.environment

      res = cmd.execute { "--environment", "cool", "debug" }
      assert.same "cool", res.environment

    it "environment with arg", ->
      res = cmd.execute { "debug", "wow" }
      assert.same "wow", res.environment

    it "fails with double env", ->
      assert.has_error(
        -> cmd.execute { "--environment=umm", "debug", "wow" }
        "You tried to set the environment twice. Use either --environment or the environment argument, not both"
      )

  describe "new", ->
    before_each ->
      stub(require("lapis.cmd.nginx"), "find_nginx").returns true

    it "lapis new", ->
      cmd.execute { "new" }

      assert_files {
        "app.lua", "config.lua", "mime.types", "models.lua", "nginx.conf"
      }

    it "lapis new --moonscript", ->
      cmd.execute { "new", "--moonscript" }

      assert_files {
        "app.moon", "config.moon", "mime.types", "models.moon", "nginx.conf"
      }

    it "fails if files already exist", ->
      cmd.execute { "new" }
      assert.has_error ->
        cmd.execute { "new" }

    it "lapis new --cqueues", ->
      -- --forsce to bypass the module dependency check
      cmd.execute { "new", "--cqueues", "--force" }
      assert_files { "app.lua", "config.lua", "models.lua" }

    it "lapis new --etlua-config", ->
      cmd.execute { "new", "--etlua-config" }

      assert_files {
        "app.lua", "config.lua", "mime.types", "models.lua", "nginx.conf.etlua"
      }

    it "lapis new --tup", ->
      cmd.execute { "new", "--tup" }
      assert_files {
        "app.lua", "config.lua", "mime.types", "models.lua", "nginx.conf", "Tupfile", "Tuprules.tup"
      }

    it "lapis new --git", ->
      cmd.execute { "new", "--git" }
      assert_files {
        "app.lua", "config.lua", "mime.types", "models.lua", "nginx.conf", ".gitignore"
      }

  describe "build", ->
    it "lapis build", ->
      cmd.execute { "new" }
      cmd.execute { "build" }

      assert_files {
        "app.lua", "config.lua", "mime.types", "models.lua", "nginx.conf", "nginx.conf.compiled"
      }

  describe "generate", ->
    it "lapis generate model things", ->
      cmd.execute { "generate", "model", "things" }
      assert_files { "models/things.lua" }

    it "lapis generate model --moonscript things", ->
      cmd.execute { "generate", "model", "things", "--moonscript" }
      assert_files { "models/things.moon" }

    it "lapis generate spec models.things", ->
      cmd.execute { "generate", "spec", "models.things" }
      assert_files { "spec/models/things_spec.lua" }

    it "lapis generate spec models.things --moonscript", ->
      cmd.execute { "generate", "spec", "models.things", "--moonscript" }
      assert_files { "spec/models/things_spec.moon" }

    it "lapis generate migration in lua", ->
      cmd.execute { "generate", "migration", "--lua" }
      cmd.execute { "generate", "migration", "--lua" } -- appends a new migration
      assert_files { "migrations.lua" }

      -- load the file to ensure it's valid Lua syntax
      assert loadfile("migrations.lua")

    it "lapis generate migration in lua", ->
      cmd.execute { "generate", "migration", "--moon" }
      cmd.execute { "generate", "migration", "--moon" } -- appends a new migration
      assert_files { "migrations.moon" }

      -- load file to ensure it's valid moonscript -> lua syntax
      assert require("moonscript.base").loadfile "migrations.moon"

    it "lapis generate rockspec", ->
      cmd.execute { "generate", "rockspec" }
      cmd.execute { "generate", "rockspec", "--moon", "--sqlite", "--version-name=dev-2", "--app-name=lapis-thing" }

      assert_files {
        "lapis-thing-dev-2.rockspec"
        "spec-tmp-app-dev-1.rockspec"
      }

      -- verify that they are valid lua
      assert loadfile("lapis-thing-dev-2.rockspec")
      assert loadfile("spec-tmp-app-dev-1.rockspec")

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


