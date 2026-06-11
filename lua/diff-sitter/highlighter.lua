local M = {}

local function get_namespace(state)
  if state and state.ns then
    return state.ns
  end
  return vim.api.nvim_create_namespace("diff-sitter")
end

local function get_query(lang)
  if vim.treesitter.query and vim.treesitter.query.get then
    local ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
    if ok then
      return query
    end
  end
  if vim.treesitter.get_query then
    local ok, query = pcall(vim.treesitter.get_query, lang, "highlights")
    if ok then
      return query
    end
  end
  return nil
end

local function capture_name(query, id)
  local name = query.captures and query.captures[id]
  if not name then
    return nil
  end
  if name:sub(1, 1) ~= "@" then
    name = "@" .. name
  end
  return name
end

local function set_segment(bufnr, ns, row_map, start_row, start_col, end_row, end_col, hl_group, priority)
  for row = start_row, end_row do
    local map = row_map[row]
    if map then
      local line_start = row == start_row and start_col or 0
      local line_end = row == end_row and end_col or nil
      if line_end == nil then
        local line = vim.api.nvim_buf_get_lines(bufnr, map.source_row, map.source_row + 1, false)[1] or ""
        line_end = math.max(#line - map.code_col_offset, 0)
      end
      if line_end > line_start then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, map.source_row, line_start + map.code_col_offset, {
          end_row = map.source_row,
          end_col = line_end + map.code_col_offset,
          hl_group = hl_group,
          priority = priority or 110,
        })
      end
    end
  end
end

local function wipe(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

local function apply_hunk(source_bufnr, ns, hunk, config)
  if not hunk.lang or not hunk.code_lines or #hunk.code_lines == 0 then
    return
  end

  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].buftype = "nofile"
  vim.bo[scratch].bufhidden = "wipe"
  vim.bo[scratch].swapfile = false

  local ok = pcall(function()
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, hunk.code_lines)
  end)
  if not ok then
    wipe(scratch)
    return
  end

  local parser_ok, parser = pcall(vim.treesitter.get_parser, scratch, hunk.lang)
  if not parser_ok or not parser then
    wipe(scratch)
    return
  end

  local parse_ok, trees = pcall(parser.parse, parser)
  if not parse_ok or not trees or not trees[1] then
    wipe(scratch)
    return
  end

  local query = get_query(hunk.lang)
  if not query then
    wipe(scratch)
    return
  end

  local root = trees[1]:root()
  local iter_ok, iter = pcall(function()
    return query:iter_captures(root, scratch, 0, #hunk.code_lines)
  end)
  if not iter_ok or not iter then
    wipe(scratch)
    return
  end

  for id, node, metadata in iter do
    local hl_group = capture_name(query, id)
    if hl_group then
      local range = { node:range() }
      local start_row, start_col, end_row, end_col = range[1], range[2], range[3], range[4]
      if metadata and metadata.range then
        start_row, start_col, end_row, end_col = unpack(metadata.range)
      end
      set_segment(source_bufnr, ns, hunk.row_map, start_row, start_col, end_row, end_col, hl_group, config and config.priority)
    end
  end

  wipe(scratch)
end

function M.apply(bufnr, extracted_hunks, state, config)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local ns = get_namespace(state)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, hunk in ipairs(extracted_hunks or {}) do
    -- Best-effort highlighting: skip failed hunks.
    pcall(apply_hunk, bufnr, ns, hunk, config or {})
  end
end

return M
