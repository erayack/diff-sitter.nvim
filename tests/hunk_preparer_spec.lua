dofile("tests/minimal_init.lua")
local preparer = require("diff-sitter.hunk_preparer")

local function buffer_with(lines)
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  return b
end

local function expect_lua_hunks(lines, config)
  local out = preparer.prepare(buffer_with(lines), config or { max_hunk_lines = 100 })
  -- Test support only: the core highlighting path depends on an optional Tree-sitter parser.
  if not preparer._has_parser("lua") then
    eq(#out, 0)
    return nil
  end
  return out
end

test("prepares hunks across git headers paths multiple files and hunks", function()
  local out = expect_lua_hunks({
    "commit prose",
    "diff --git a/src/main.lua b/src/main.lua",
    "--- a/src/main.lua",
    "+++ b/src/main.lua",
    "@@ -1 +1 @@",
    "-local old = 1",
    "+local new = 1",
    "@@ -9 +9 @@",
    " local ctx = 1",
    "diff --git a/a.lua b/a.lua",
    "--- a/a.lua",
    "+++ b/a.lua",
    "@@ -1 +1 @@",
    "+local x = 1",
  })
  if not out then
    return
  end

  eq(#out, 3)
  eq(out[1].source_start_row, 5)
  eq(out[1].source_end_row, 7)
  eq(out[1].code_lines, { "local old = 1", "local new = 1" })
  eq(out[2].source_start_row, 8)
  eq(out[2].code_lines, { "local ctx = 1" })
  eq(out[3].source_start_row, 13)
  eq(out[3].code_lines, { "local x = 1" })
end)

test("prepares added file hunks from /dev/null headers", function()
  local out = expect_lua_hunks({ "--- /dev/null", "+++ b/new.lua", "@@ -0,0 +1 @@", "+local x = 1" })
  if not out then
    return
  end

  eq(#out, 1)
  eq(out[1].source_start_row, 3)
  eq(out[1].source_end_row, 4)
  eq(out[1].code_lines, { "local x = 1" })
end)

test("prepares hunks for quoted diff git paths with spaces", function()
  local out = expect_lua_hunks({
    'diff --git "a/foo bar.lua" "b/foo bar.lua"',
    '--- "a/foo bar.lua"',
    '+++ "b/foo bar.lua"',
    "@@ -1 +1 @@",
    "+local x = 1",
  })
  if not out then
    return
  end

  eq(#out, 1)
  eq(out[1].source_start_row, 4)
  eq(out[1].source_end_row, 5)
  eq(out[1].code_lines, { "local x = 1" })
end)

test("prepares hunks for quoted header-only paths with spaces and metadata", function()
  local out = expect_lua_hunks({
    '--- "a/foo bar.lua"    2026-01-01',
    '+++ "b/foo bar.lua"    2026-01-01',
    "@@ -1 +1 @@",
    "+local x = 1",
  })
  if not out then
    return
  end

  eq(#out, 1)
  eq(out[1].source_start_row, 3)
  eq(out[1].source_end_row, 4)
  eq(out[1].code_lines, { "local x = 1" })
end)

test("prepares hunks for quoted paths with escaped quotes", function()
  local out = expect_lua_hunks({
    'diff --git "a/foo\\"bar.lua" "b/foo\\"bar.lua"',
    '--- "a/foo\\"bar.lua"',
    '+++ "b/foo\\"bar.lua"',
    "@@ -1 +1 @@",
    "+local x = 1",
  })
  if not out then
    return
  end

  eq(#out, 1)
  eq(out[1].code_lines, { "local x = 1" })
end)

test("caches unresolved path language detection misses", function()
  local original_match = vim.filetype.match
  local calls = 0
  vim.filetype.match = function(args)
    if args and args.filename == "cache-miss.unknown_cache_ext_xyz" then
      calls = calls + 1
      return nil
    end
    return original_match(args)
  end

  local ok_call, err = pcall(function()
    local lines = {
      "diff --git a/cache-miss.unknown_cache_ext_xyz b/cache-miss.unknown_cache_ext_xyz",
      "@@",
      "+x",
    }
    eq(#preparer.prepare_lines(0, lines, {}), 0)
    eq(#preparer.prepare_lines(0, lines, {}), 0)
  end)
  vim.filetype.match = original_match

  if not ok_call then
    error(err)
  end
  eq(calls, 1)
end)

test("caches missing parser checks", function()
  local original_add = vim.treesitter.language and vim.treesitter.language.add
  if not original_add then
    return
  end

  local calls = 0
  vim.treesitter.language.add = function(lang)
    if lang == "missing_cache_lang_xyz" then
      calls = calls + 1
      error("missing parser")
    end
    return original_add(lang)
  end

  local ok_call, err = pcall(function()
    eq(preparer._has_parser("missing_cache_lang_xyz"), false)
    eq(preparer._has_parser("missing_cache_lang_xyz"), false)
  end)
  vim.treesitter.language.add = original_add

  if not ok_call then
    error(err)
  end
  eq(calls, 1)
end)

test("treats hunk body --- and +++ lines as code lines", function()
  local out = expect_lua_hunks({
    "diff --git a/init.lua b/init.lua",
    "--- a/init.lua",
    "+++ b/init.lua",
    "@@ -1,4 +1,4 @@",
    "--- local old_value = 1",
    "+++ local new_value = 1",
    "-local removed = 1",
    "+local added = 1",
  })
  if not out then
    return
  end

  eq(#out, 1)
  eq(out[1].code_lines, {
    "-- local old_value = 1",
    "++ local new_value = 1",
    "local removed = 1",
    "local added = 1",
  })
  eq(out[1].row_map[0].source_row, 4)
  eq(out[1].row_map[1].source_row, 5)
end)

test("prepares highlight-ready hunks with row maps", function()
  local out = expect_lua_hunks({
    "diff --git a/init.lua b/init.lua",
    "--- a/init.lua",
    "+++ b/init.lua",
    "@@ -1 +1 @@",
    "-local x = 1",
    "+local x = 1",
    " local x = 1",
    "\\ No newline at end of file",
  }, { max_hunk_lines = 10 })
  if not out then
    return
  end

  eq(#out, 1)
  eq(out[1].lang, "lua")
  eq(out[1].code_lines, { "local x = 1", "local x = 1", "local x = 1" })
  eq(out[1].row_map[0].source_row, 4)
  eq(out[1].row_map[0].code_col_offset, 1)
  eq(out[1].row_map[0].kind, "delete")
  eq(out[1].row_map[1].kind, "add")
  eq(out[1].row_map[2].kind, "context")
end)

test("skips empty oversized and unknown-language hunks", function()
  local unknown = buffer_with({
    "diff --git a/file.unknown_extension_xyz b/file.unknown_extension_xyz",
    "@@",
    "+x",
  })
  eq(#preparer.prepare(unknown, {}), 0)

  local oversized =
    buffer_with({ "diff --git a/init.lua b/init.lua", "@@", "\\ No newline at end of file", "+local x = 1" })
  eq(#preparer.prepare(oversized, { max_hunk_lines = 1 }), 0)

  local empty = buffer_with({ "diff --git a/init.lua b/init.lua", "@@", "\\ No newline at end of file" })
  eq(#preparer.prepare(empty, {}), 0)
end)

test("unknown and missing language inputs do not throw", function()
  local ok_call = pcall(function()
    preparer.prepare(
      buffer_with({ "diff --git a/file.unknown_extension_xyz b/file.unknown_extension_xyz", "@@", "+x" }),
      {}
    )
    preparer.prepare_lines(0, { "@@", "+x" }, {})
  end)
  ok(ok_call)
end)

run_tests()
