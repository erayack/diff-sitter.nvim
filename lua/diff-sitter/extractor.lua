local M = {}

local function kind_for_prefix(prefix)
  if prefix == "+" then
    return "add"
  elseif prefix == "-" then
    return "delete"
  elseif prefix == " " then
    return "context"
  end
end

local function extract_hunk(bufnr, file, hunk, lang, config)
  local line_count = hunk.body_end_row - hunk.body_start_row
  if config and config.max_hunk_lines and line_count > config.max_hunk_lines then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, hunk.body_start_row, hunk.body_end_row, false)
  local code_lines = {}
  local row_map = {}

  for idx, line in ipairs(lines) do
    if not line:match("^\\ No newline at end of file") then
      local prefix = line:sub(1, 1)
      local kind = kind_for_prefix(prefix)
      if kind then
        table.insert(code_lines, line:sub(2))
        row_map[#code_lines - 1] = {
          source_row = hunk.body_start_row + idx - 1,
          code_col_offset = 1,
          kind = kind,
        }
      end
    end
  end

  if #code_lines == 0 then
    return nil
  end

  return {
    lang = lang or file.lang,
    source_bufnr = bufnr,
    source_start_row = hunk.body_start_row,
    source_end_row = hunk.body_end_row,
    code_lines = code_lines,
    row_map = row_map,
  }
end

function M.extract(bufnr, files, config)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end

  local extracted = {}
  for _, file in ipairs(files or {}) do
    local lang = file.lang or file.language
    if lang then
      for _, hunk in ipairs(file.hunks or {}) do
        local item = extract_hunk(bufnr, file, hunk, lang, config or {})
        if item then
          table.insert(extracted, item)
        end
      end
    end
  end
  return extracted
end

return M
