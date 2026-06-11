dofile("tests/minimal_init.lua")
local extractor = require("diff-sitter.extractor")

test("strips prefixes and maps rows and columns", function()
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, {
    "@@ -1 +1 @@",
    "-local x = 1",
    "+local x = 1",
    " local x = 1",
    "\\ No newline at end of file",
  })
  local out = extractor.extract(b, { { lang = "lua", hunks = { { body_start_row = 1, body_end_row = 5 } } } }, { max_hunk_lines = 10 })
  eq(#out, 1)
  eq(out[1].code_lines, { "local x = 1", "local x = 1", "local x = 1" })
  eq(out[1].row_map[0].source_row, 1)
  eq(out[1].row_map[0].code_col_offset, 1)
  eq(out[1].row_map[0].kind, "delete")
  eq(out[1].row_map[1].kind, "add")
  eq(out[1].row_map[2].kind, "context")
end)

test("skips empty and oversized hunks", function()
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, { "@@", "\\ No newline at end of file", "+x" })
  eq(#extractor.extract(b, { { lang = "lua", hunks = { { body_start_row = 1, body_end_row = 2 } } } }, {}), 0)
  eq(#extractor.extract(b, { { lang = "lua", hunks = { { body_start_row = 1, body_end_row = 3 } } } }, { max_hunk_lines = 1 }), 0)
end)

run_tests()
