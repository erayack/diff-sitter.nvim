dofile("tests/minimal_init.lua")
local hunk_preparer = require("diff-sitter.hunk_preparer") -- test support for optional parser checks

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
  if hunk_preparer._has_parser("lua") then
    ok(#marks > 0)
    ok(marks[1][3] >= 1)
  end
  ds.disable(b)
  eq(ds.is_enabled(b), false)
  eq(#vim.api.nvim_buf_get_extmarks(b, ns, 0, -1, {}), 0)
end)

test("hunk body header-like lines do not prevent highlighting", function()
  if not hunk_preparer._has_parser("lua") then
    return
  end

  local ds = require("diff-sitter")
  ds.setup({ debounce_ms = 1 })
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, {
    "diff --git a/init.lua b/init.lua",
    "--- a/init.lua",
    "+++ b/init.lua",
    "@@ -1,4 +1,4 @@",
    "--- local old_header_like = 1",
    "+++ local new_header_like = 1",
    "-local old_value = 1",
    "+local new_value = 1",
  })

  ds.enable(b)
  ds.refresh(b)

  local ns = vim.api.nvim_create_namespace("diff-sitter")
  local marks = vim.api.nvim_buf_get_extmarks(b, ns, 0, -1, { details = true })
  local saw_header_like_body_row = false
  for _, mark in ipairs(marks) do
    if mark[2] == 4 then
      saw_header_like_body_row = true
    end
  end
  ok(saw_header_like_body_row, "expected highlighting on the --- hunk body line")

  ds.disable(b)
end)

run_tests()
