--!strict

local PropertyInspector = require("../src/Runtime/PropertyInspector")

assert(PropertyInspector.FormatValue("hello") == "hello", "String formatting failed")
assert(PropertyInspector.FormatValue(true) == "true", "Boolean formatting failed")
assert(PropertyInspector.FormatValue(false) == "false", "Boolean formatting failed")
assert(PropertyInspector.FormatValue(12.5) == "12.5", "Number formatting failed")

local okNumber, parsedNumber = PropertyInspector.ParseValue("42.5", 1)
assert(okNumber == true, "Number parsing should succeed")
assert(parsedNumber == 42.5, "Number parsing returned the wrong value")

local badNumber = PropertyInspector.ParseValue("abc", 1)
assert(badNumber == false, "Invalid number parsing should fail")

local okTrue, parsedTrue = PropertyInspector.ParseValue("yes", false)
assert(okTrue == true and parsedTrue == true, "Boolean true parsing failed")

local okFalse, parsedFalse = PropertyInspector.ParseValue("off", true)
assert(okFalse == true and parsedFalse == false, "Boolean false parsing failed")

local okString, parsedString = PropertyInspector.ParseValue("  keep spaces  ", "")
assert(okString == true, "String parsing should succeed")
assert(parsedString == "  keep spaces  ", "String parsing should preserve input")

print("PropertyInspector tests passed")
