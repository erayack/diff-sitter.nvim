dofile("tests/minimal_init.lua")
local language = require("diff-sitter.language")

test("setup is idempotent after plugin initialization", function()
  local ds = require("diff-sitter")
  ds.setup({ debounce_ms = 1 })
  ds.setup({ debounce_ms = 1 })
  ok(true)
end)

test("enable refresh disable integration", function()
  local ds = require("diff-sitter")
  ds.setup({ debounce_ms = 1 })
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, {
    "diff --git a/init.lua b/init.lua",
    "--- a/init.lua",
    "+++ b/init.lua",
    "@@ -1,3 +1,3 @@",
    "-local x = 1",
    "+local y = 2",
    " print(y)",
  })
  ds.enable(b)
  ok(ds.is_enabled(b))
  ds.refresh(b)
  local ns = vim.api.nvim_create_namespace("diff-sitter")
  local marks = vim.api.nvim_buf_get_extmarks(b, ns, 0, -1, { details = true })
  if language.has_parser("lua") then
    ok(#marks > 0)
    ok(marks[1][3] >= 1)
  end
  ds.disable(b)
  eq(ds.is_enabled(b), false)
  eq(#vim.api.nvim_buf_get_extmarks(b, ns, 0, -1, {}), 0)
end)

run_tests()
