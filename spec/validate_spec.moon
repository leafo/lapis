
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