
import validate from require "lapis.validate"

o = {
  age: ""
  name: "abc"
  height: "12234234"
}

tests = {
  {
    {
      { "age", exists: true }
      { "name", exists: true }
      { "rupture", exists: true, "CUSTOM MESSAGE COOL" }
    }

    { "age must be provided", "CUSTOM MESSAGE COOL" }
  }

  {
    {
      { "name", exists: true, min_length: 4 }
      { "age", min_length: 4 }
      { "height", max_length: 5 }
    }

    {
      "name must be at least 4 chars"
      "age must be at least 4 chars"
      "height must be at most 5 chars"
    }
  }

  {
    {
      { "height", is_integer: true }
      { "name", is_integer: true }
      { "age", is_integer: true }
    }

    {
      "name must be an integer"
      "age must be an integer"
    }
  }

  {
    {
      { "height", min_length: 4 }
    }

    nil
  }

  {
    {
      { "age", optional: true, max_length: 2 }
      { "name", optional: true, max_length: 2 }
    }

    {
      "name must be at most 2 chars"
    }
  }

  {
    {
      { "name", one_of: {"cruise", "control" } }
    }

    {
      "name must be one of cruise, control"
    }
  }

  {
    {
      { "name", one_of: {"bcd", "abc" } }
    }
  }


  {
    {
      { "name", matches_pattern: "bc$" }
      { "age", matches_pattern: "." }
    }

    {
      "age is not the right format"
    }
  }

}


describe "lapis.validate", ->
  for {input, output} in *tests
    it "should match", ->
      errors = validate o, input
      assert.same errors, output
  
  it "should get key with error", ->
    errors = validate o, {
      { "age", exists: true }
      { "name", exists: true }
      { "rupture", exists: true, "rupture is required" }
    }, {keys: true }
    assert.same errors, {
      age: "age must be provided",
      rupture: "rupture is required"
    }

describe "lapis.validate.types", ->
  run_with_errors = (fn) ->
    import capture_errors from require "lapis.application"
    req = {}
    capture_errors(fn) req
    req.errors

  it "creates assert type", ->
    import types from require "tableshape"
    import assert_error from require "lapis.validate.types"

    assert_string = assert_error(types.string)

    assert.same {
      [[expected type "string", got "number"]]
    }, run_with_errors ->
      assert_string 77

    assert.same nil, run_with_errors ->
      assert_string "hello"

  describe "ValidateParamsType", ->
    import types from require "tableshape"
    import assert_error, validate_params from require "lapis.validate.types"

    it "works with assert_error", ->
      t = assert_error validate_params {
        {"good", types.one_of {"yes", "no"} }
        {"dog", types.string\tag "sweet"}
      }

      assert.same {
        [[good: expected "yes", or "no"]]
        [[dog: expected type "string", got "nil"]]
      }, run_with_errors ->
        t\transform {}

      assert.same {
        {
          dog: "fool"
          good: "no"
        }
        {
          sweet: "fool"
        }
      }, {
        t\transform { good: "no", dog: "fool", bye: "heheh" }
      }

    it "fails to create object with invalid spec", ->
      assert.has_error(
        ->
          validate_params {
            item: "zone"
          }
        [[validate_params: Invalid validation specification object: expected type "table", got "string" (index: item)]]
      )

      assert.has_error(
        ->
          validate_params {
            {"one", "two"}
          }
        [[validate_params: Invalid validation specification object: field 2: expected tableshape type (index: 1)]]
      )

      assert.has_error(
        ->
          validate_params {
            {"one", types.string, fart: "zone"}
          }
        [[validate_params: Invalid validation specification object: extra fields: "fart" (index: 1)]]
      )

    it "tests basic object", ->
      test_object = validate_params {
        {"one", types.string}
        {"two", types.string / (s) -> "-#{s}-"}
      }

      assert.same {
        nil
        {
          [[params: expected type "table", got "string"]]
        }
      }, { test_object "wtf" }

      assert.same {
        nil
        {
          [[params: expected type "table", got "nil"]]
        }
      }, { test_object! }

      assert.same {
        nil
        {
          [[one: expected type "string", got "nil"]]
          [[two: expected type "string", got "nil"]]
        }
      }, { test_object {} }
 
      assert.same {
        nil
        {
          [[one: expected type "string", got "number"]]
          [[two: expected type "string", got "boolean"]]
        }
      }, { test_object {one: 55, two: true, whatthe: "heck"} }

      assert.same {
        nil
        {
          [[two: expected type "string", got "nil"]]
        }
      }, { test_object { one: "yes", another: false } }

      assert.same {
        nil
        {
          [[one: expected type "string", got "boolean"]]
        }
      }, { test_object { two: "sure", one: false } }

      assert.same {
        {
          one: "whoa"
          two: "-sure-"
        }
      }, { test_object\transform { two: "sure", one: "whoa", ignore: 99 } }

    it "tests object with state", ->

    it "test nested validate", ->
      test_object = validate_params {
        {"alpha", types.one_of {"one", "two"} }
        {"two", validate_params {
          {"one", as: "sure", error: "you messed up", types.string\tag "one"}
          {"two", label: "The Two", types.string / (s) -> "-#{s}-"}
        }}

        {"optional", label: "Optionals", types.nil + validate_params {
          {"confirm", types.literal "true" }
        }}
      }

      assert.same [[
params type {
  alpha: "one", or "two"
  two: params type {
    one: type "string" tagged "one"
    two: type "string"
  }
  optional: type "nil", or params type {confirm: "true"}
}]], tostring test_object

      assert.same {
        nil
        {
          [[alpha: expected "one", or "two"]]
          [[two: params: expected type "table", got "nil"]]
        }
      }, { test_object {} }

      assert.same {
        nil
        {
          [[alpha: expected "one", or "two"]]
          [[two: params: expected type "table", got "nil"]]
          [[Optionals: expected type "nil", or params type {confirm: "true"}]]
        }
      }, { test_object { optional: "fart"} }

      assert.same {
        nil
        {
          [[alpha: expected "one", or "two"]]
          [[two: you messed up]]
          [[two: The Two: expected type "string", got "nil"]]
          [[Optionals: expected type "nil", or params type {confirm: "true"}]]
        }
      }, { test_object { optional: {}, two: {}} }

      assert.same {
        nil
        {
          [[Optionals: expected type "nil", or params type {confirm: "true"}]]
        }
      }, { test_object { optional: {}, alpha: "one", two: {one: "yes", two: "no"}} }


      assert.same {
        {
          alpha: "one"
          optional: {confirm: "true"}
          two: {
            sure: "yes"
            two: "-no-"
          }
        }
      }, { test_object\transform { optional: { confirm: "true", junk: "yes"}, alpha: "one", two: {1,2,3, for: true, one: "yes", two: "no"}} }

    describe "valid_text", ->
      import valid_text from require "lapis.validate.types"

      it "invalid type", ->
        assert.same {
          nil
          "expected valid text"
        }, {
          valid_text\transform 100
        }

        assert.same {
          nil
          "expected valid text"
        }, {
          valid_text\transform nil
        }

      it "empty string", ->
        assert.same {
          ""
        }, {
          valid_text\transform ""
        }

      it "regular string", ->
        assert.same {
          "hello world\r\nyeah"
        }, {
          valid_text\transform "hello world\r\nyeah"
        }

      it "removes bad chars", ->
        assert.same {
          nil
          "expected valid text"
        }, {
          valid_text\transform "\008\000umm\127and\200f"
        }
   
    describe "trimmed_text", ->
      import trimmed_text from require "lapis.validate.types"

      it "empty string", ->
        assert.same {
          nil
          "expected text"
        }, {
          trimmed_text\repair ""
        }

      it "nil value", ->
        assert.same {
          nil
          'expected valid text'
        }, {
          trimmed_text\repair nil
        }

      it "bad type", ->
        assert.same {
          nil
          'expected valid text'
        }, {
          trimmed_text\repair {}
        }

      it "trims text", ->
        assert.same {
          "trimz"
        }, {
          trimmed_text\transform " trimz   "
        }

    describe "limited_text", ->
      import limited_text, trimmed_text from require "lapis.validate.types"

      it "passes valid text", ->
        assert.same "hello", limited_text(10)\transform "hello"
        assert.same "hello", limited_text(5)\transform "hello"
        assert.same "hello", limited_text(10)\transform "   hello           "
        assert.same "hello", limited_text(10)\transform "  hello   \t  \n    "

        assert.same "💁👌🎍😍", limited_text(4)\transform "💁👌🎍😍"

      it "fails invalid input", ->
        assert.same {nil, "expected text between 1 and 4 characters"}, { limited_text(4)\transform "\0\0\0" }

      it "fails with text outside range", ->
        assert.same {nil, "expected text between 1 and 10 characters"}, { limited_text(10)\transform "helloworldthisfails" }
        assert.same {nil, "expected text between 1 and 10 characters"}, { limited_text(10)\transform "" }

    describe "truncated_text", ->
      import truncated_text from require "lapis.validate.types"

      it "invalid input", ->
        assert.same {
          nil,
          "expected valid text"
        }, {
          truncated_text(5)\transform true
        }

      it "empty string", ->
        assert.same {
          nil,
          "expected text"
        }, {
          truncated_text(5)\transform ""
        }

      it "1 char string", ->
        assert.same {
          "a"
        }, {
          truncated_text(5)\transform "a"
        }

      it "5 char string", ->
        assert.same {
          "abcde"
        }, {
          truncated_text(5)\transform "abcde"
        }

      it "6 char string", ->
        assert.same {
          "abcde"
        }, {
          truncated_text(5)\transform "abcdef"
        }

      it "very long strong", ->
        assert.same {
          "abcde"
        }, {
          truncated_text(5)\transform "abcdef"\rep 100
        }

      it "unicode string", ->
        assert.same {
          "基本上獲得"
        }, {
          truncated_text(5)\transform "基本上獲得全國軍"
        }


    it "db_id", ->
      import db_id from require "lapis.validate.types"
      assert.same {nil, "expected database ID integer"}, {db_id\transform "5.5"}
      assert.same {nil, "expected database ID integer"}, {db_id\transform 5.5}

      assert.same {5}, {db_id\transform 5}
      assert.same {5}, {db_id\transform "5"}
      assert.same {5}, {db_id\transform " 5"}
      assert.same {nil, "expected database ID integer"}, {db_id\transform "fjwekfwejfwe"}

      assert.same {0}, {db_id\transform "0"}
      assert.same {0}, {db_id\transform 0}
      assert.same {
        nil
        "expected database ID integer"
      }, {db_id\transform "239203280932932803023920302302302032203280328038203820380232802032083232239023820328903283209382039238209382032"}

      -- too large number
      assert.same {
        nil
        "expected database ID integer"
      }, {db_id\transform "92147483647"}

      -- too large number
      assert.same {
        nil
        "expected database ID integer"
      }, {db_id\transform "-34"}

      assert.same {
        nil
        "expected database ID integer"
      }, {db_id\transform -1}

      assert.same {
        nil
        "expected database ID integer"
      }, {db_id\transform 10^18}

    it "db_enum", ->
      import db_enum from require "lapis.validate.types"
      import enum from require "lapis.db.base_model"

      Types = enum {
        default: 1
        flash: 2
        unity: 3
        java: 4
        html: 5
      }

      t = db_enum Types

      assert.same {
        Types.flash
      }, { t\transform "flash" }

      assert.same {
        Types.flash
      }, { t\transform Types.flash }

      assert.same {
        Types.flash
      }, { t\transform "#{Types.flash }" }

      assert.same {
        nil
        "expected enum(default, flash, unity, java, html)"
      }, { t\transform "flahs" }

      assert.same {
        nil
        "expected enum(default, flash, unity, java, html)"
      }, { t\transform "9" }

      assert.same {
        nil
        "expected enum(default, flash, unity, java, html)"
      }, { t\transform 9 }

