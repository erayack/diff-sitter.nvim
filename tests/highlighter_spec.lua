dofile("tests/minimal_init.lua")
local highlighter = require("diff-sitter.highlighter")
local hunk_preparer = require("diff-sitter.hunk_preparer") -- test support for optional parser checks

-- These tests exercise the intentional highlighter.apply seam. Synthetic hunks are
-- the accepted input contract here; diff parsing/preparation behavior belongs in
-- hunk_preparer or public integration tests.
test("missing parser skips hunk and clears stale namespace marks", function()
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, { "+local x = 1" })
  local ns = vim.api.nvim_create_namespace("diff-sitter-test-missing")
  vim.api.nvim_buf_set_extmark(b, ns, 0, 1, { end_col = 2, hl_group = "Comment" })
  highlighter.apply(b, { { lang = "missing_lang_xyz", code_lines = { "local x = 1" }, row_map = { [0] = { source_row = 0, code_col_offset = 1 } } } }, { ns = ns }, {})
  eq(#vim.api.nvim_buf_get_extmarks(b, ns, 0, -1, {}), 0)
end)

test("lua parser places source extmarks after prefix when available", function()
  if not hunk_preparer._has_parser("lua") then
    return
  end
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, { "+local x = 1" })
  local ns = vim.api.nvim_create_namespace("diff-sitter-test-lua")
  highlighter.apply(b, { { lang = "lua", code_lines = { "local x = 1" }, row_map = { [0] = { source_row = 0, code_col_offset = 1 } } } }, { ns = ns }, {})
  local marks = vim.api.nvim_buf_get_extmarks(b, ns, 0, -1, { details = true })
  ok(#marks > 0)
  ok(marks[1][3] >= 1, "mark must start after diff prefix")
end)

test("multiline captures use valid source line end columns", function()
  if not hunk_preparer._has_parser("lua") then
    return
  end
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, { "+--[[", "+hello", "+]]" })
  local ns = vim.api.nvim_create_namespace("diff-sitter-test-multiline")
  highlighter.apply(b, {
    {
      lang = "lua",
      code_lines = { "--[[", "hello", "]]" },
      row_map = {
        [0] = { source_row = 0, code_col_offset = 1 },
        [1] = { source_row = 1, code_col_offset = 1 },
        [2] = { source_row = 2, code_col_offset = 1 },
      },
    },
  }, { ns = ns }, {})
  local marks = vim.api.nvim_buf_get_extmarks(b, ns, 0, -1, { details = true })
  local saw_middle_row = false
  for _, mark in ipairs(marks) do
    if mark[2] == 1 then
      saw_middle_row = true
      ok(mark[4].end_col and mark[4].end_col > mark[3], "middle-row multiline mark must have a valid end_col")
    end
  end
  ok(saw_middle_row, "expected a multiline capture segment on the middle row")
end)

run_tests()
