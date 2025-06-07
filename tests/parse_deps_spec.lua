local parse_lines = require("npm-lens")._parse_lines

describe("npm-lens.parse_deps", function()
  it("should parse an empty file", function()
    assert.are.same({}, parse_lines {})
  end)

  it("should parse a file with one dependency in dependencies section", function()
    assert.are.same(
      {
        {
          name = "package-name",
          current = "1.0.0",
          wanted = nil,
          latest = nil,
          linenr = 3,
        },
      },
      parse_lines {
        "{",
        '  "name": "testing"',
        '  "dependencies": {',
        '    "package-name": "^1.0.0"',
        "  }",
        "}",
      }
    )
  end)

  it("should parse a file with one dependency in devDependencies section", function()
    assert.are.same(
      {
        {
          name = "package-name",
          current = "1.0.0",
          wanted = nil,
          latest = nil,
          linenr = 3,
        },
      },
      parse_lines {
        "{",
        '  "name": "testing"',
        '  "devDependencies": {',
        '    "package-name": "~1.0.0"',
        "  }",
        "}",
      }
    )
  end)

  it("should parse a file with two deps, one in each section", function()
    assert.are.same(
      {
        {
          name = "package-name",
          current = "1.0.0",
          wanted = nil,
          latest = nil,
          linenr = 3,
        },
        {
          name = "package-name2",
          current = "1.0.0",
          wanted = nil,
          latest = nil,
          linenr = 6,
        },
      },
      parse_lines {
        "{",
        '  "name": "testing"',
        '  "dependencies": {',
        '    "package-name": "1.0.0"',
        "  }",
        '  "devDependencies": {',
        '    "package-name2": "1.0.0"',
        "  }",
        "}",
      }
    )
  end)
end)
