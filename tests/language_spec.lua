dofile("tests/minimal_init.lua")
local language = require("diff-sitter.language")

test("unknown and missing inputs do not throw", function()
  eq(language.detect(nil), nil)
  local ok_call = pcall(function() language.detect("file.unknown_extension_xyz") end)
  ok(ok_call)
end)

test("common extension returns parser-backed language when installed", function()
  local detected = language.detect("init.lua")
  if language.has_parser("lua") then
    eq(detected, "lua")
  else
    eq(detected, nil)
  end
end)

run_tests()
