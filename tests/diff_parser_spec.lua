dofile("tests/minimal_init.lua")
local parser = require("diff-sitter.diff_parser")

test("parses git headers, paths, multiple files and hunks", function()
  local files = parser.parse_lines({
    "commit prose",
    "diff --git a/src/main.rs b/src/main.rs",
    "--- a/src/main.rs",
    "+++ b/src/main.rs",
    "@@ -1 +1 @@",
    "-old",
    "+new",
    "@@ -9 +9 @@",
    " ctx",
    "diff --git a/a.lua b/a.lua",
    "--- a/a.lua",
    "+++ b/a.lua",
    "@@ -1 +1 @@",
    "+x",
  })
  eq(#files, 2)
  eq(files[1].old_path, "src/main.rs")
  eq(files[1].new_path, "src/main.rs")
  eq(#files[1].hunks, 2)
  eq(files[1].hunks[1].header_row, 4)
  eq(files[1].hunks[1].body_start_row, 5)
  eq(files[1].hunks[1].body_end_row, 7)
  eq(files[2].new_path, "a.lua")
  eq(files[2].hunks[1].body_end_row, 14)
end)

test("parses added and deleted file headers", function()
  local files = parser.parse_lines({ "--- /dev/null", "+++ b/new.lua", "@@ -0,0 +1 @@", "+x" })
  eq(files[1].old_path, nil)
  eq(files[1].new_path, "new.lua")
  eq(files[1].hunks[1].body_end_row, 4)
end)

test("does not treat hunk body --- and +++ lines as file headers", function()
  local files = parser.parse_lines({
    "diff --git a/doc.md b/doc.md",
    "--- a/doc.md",
    "+++ b/doc.md",
    "@@ -1,4 +1,4 @@",
    "--- old markdown rule",
    "+++ new markdown rule",
    "-old",
    "+new",
  })
  eq(#files, 1)
  eq(files[1].old_path, "doc.md")
  eq(files[1].new_path, "doc.md")
  eq(files[1].hunks[1].body_end_row, 8)
end)

run_tests()
