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
  highlighter.apply(b, {
    {
      lang = "missing_lang_xyz",
      code_lines = { "local x = 1" },
      row_map = { [0] = { source_row = 0, code_col_offset = 1 } },
    },
  }, { ns = ns }, {})
  eq(#vim.api.nvim_buf_get_extmarks(b, ns, 0, -1, {}), 0)
end)

test("lua parser places source extmarks after prefix when available", function()
  if not hunk_preparer._has_parser("lua") then
    return
  end
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, { "+local x = 1" })
  local ns = vim.api.nvim_create_namespace("diff-sitter-test-lua")
  highlighter.apply(
    b,
    { { lang = "lua", code_lines = { "local x = 1" }, row_map = { [0] = { source_row = 0, code_col_offset = 1 } } } },
    { ns = ns },
    {}
  )
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

test("caches missing highlight query lookups", function()
  local original_get_parser = vim.treesitter.get_parser
  local original_query_get = vim.treesitter.query and vim.treesitter.query.get
  local original_get_query = vim.treesitter.get_query
  if not original_query_get and not original_get_query then
    return
  end

  local lang = "query_cache_missing_lang"
  local query_get_calls = 0
  local get_query_calls = 0
  vim.treesitter.get_parser = function(bufnr, parser_lang)
    if parser_lang == lang then
      return {
        parse = function()
          return { {
            root = function()
              return {}
            end,
          } }
        end,
      }
    end
    return original_get_parser(bufnr, parser_lang)
  end
  if original_query_get then
    vim.treesitter.query.get = function(query_lang, name)
      if query_lang == lang and name == "highlights" then
        query_get_calls = query_get_calls + 1
        return nil
      end
      return original_query_get(query_lang, name)
    end
  end
  if original_get_query then
    vim.treesitter.get_query = function(query_lang, name)
      if query_lang == lang and name == "highlights" then
        get_query_calls = get_query_calls + 1
        return nil
      end
      return original_get_query(query_lang, name)
    end
  end

  local ok_call, err = pcall(function()
    local b = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "+local x = 1" })
    local ns = vim.api.nvim_create_namespace("diff-sitter-test-query-cache")
    local hunk =
      { lang = lang, code_lines = { "local x = 1" }, row_map = { [0] = { source_row = 0, code_col_offset = 1 } } }
    highlighter.apply(b, { hunk }, { ns = ns }, {})
    highlighter.apply(b, { hunk }, { ns = ns }, {})
  end)

  vim.treesitter.get_parser = original_get_parser
  if original_query_get then
    vim.treesitter.query.get = original_query_get
  end
  if original_get_query then
    vim.treesitter.get_query = original_get_query
  end

  if not ok_call then
    error(err)
  end
  if original_query_get then
    eq(query_get_calls, 1)
  end
  if original_get_query then
    eq(get_query_calls, 1)
  end
end)

run_tests()
