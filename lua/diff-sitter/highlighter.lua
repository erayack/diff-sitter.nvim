local M = {}

local api = vim.api
local buf_get_lines = api.nvim_buf_get_lines
local buf_set_extmark = api.nvim_buf_set_extmark

local query_cache = {}

local function get_namespace(state)
  if state and state.ns then
    return state.ns
  end
  return vim.api.nvim_create_namespace("diff-sitter")
end

local function get_query(lang)
  if query_cache[lang] ~= nil then
    return query_cache[lang]
  end

  local query = false
  if vim.treesitter.query and vim.treesitter.query.get then
    local ok, result = pcall(vim.treesitter.query.get, lang, "highlights")
    if ok and result then
      query = result
    end
  end
  if not query and vim.treesitter.get_query then
    local ok, result = pcall(vim.treesitter.get_query, lang, "highlights")
    if ok and result then
      query = result
    end
  end
  if query then
    query_cache[lang] = query
    return query
  end
  query_cache[lang] = false
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

local function set_segment(bufnr, ns, row_map, line_lengths, opts, start_row, start_col, end_row, end_col, hl_group)
  opts.hl_group = hl_group
  for row = start_row, end_row do
    local map = row_map[row]
    if map then
      local source_row = map.source_row
      local code_col_offset = map.code_col_offset
      local line_start = row == start_row and start_col or 0
      local line_end = row == end_row and end_col or nil
      if line_end == nil then
        line_end = line_lengths[source_row]
        if line_end == nil then
          local line = buf_get_lines(bufnr, source_row, source_row + 1, false)[1] or ""
          line_end = math.max(#line - code_col_offset, 0)
          line_lengths[source_row] = line_end
        end
      end
      if line_end > line_start then
        opts.end_row = source_row
        opts.end_col = line_end + code_col_offset
        pcall(buf_set_extmark, bufnr, ns, source_row, line_start + code_col_offset, opts)
      end
    end
  end
end

local function wipe(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

local function make_scratch()
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].buftype = "nofile"
  vim.bo[scratch].bufhidden = "wipe"
  vim.bo[scratch].swapfile = false
  return scratch
end

local function apply_hunk(source_bufnr, scratch, ns, hunk, line_lengths, config)
  if not hunk.lang or not hunk.code_lines or #hunk.code_lines == 0 then
    return
  end

  pcall(function()
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, hunk.code_lines)
    local parser_ok, parser = pcall(vim.treesitter.get_parser, scratch, hunk.lang)
    if not parser_ok or not parser then
      return
    end

    local parse_ok, trees = pcall(parser.parse, parser)
    if not parse_ok or not trees or not trees[1] then
      return
    end

    local query = get_query(hunk.lang)
    if not query then
      return
    end

    local root = trees[1]:root()
    local iter_ok, iter = pcall(function()
      return query:iter_captures(root, scratch, 0, #hunk.code_lines)
    end)
    if not iter_ok or not iter then
      return
    end

    local opts = { priority = (config and config.priority) or 110 }
    for id, node, metadata in iter do
      local hl_group = capture_name(query, id)
      if hl_group then
        local start_row, start_col, end_row, end_col = node:range()
        if metadata and metadata.range then
          local range = metadata.range
          start_row, start_col, end_row, end_col = range[1], range[2], range[3], range[4]
        end
        set_segment(
          source_bufnr,
          ns,
          hunk.row_map,
          line_lengths,
          opts,
          start_row,
          start_col,
          end_row,
          end_col,
          hl_group
        )
      end
    end
  end)
end

function M.apply(bufnr, extracted_hunks, state, config)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local ns = get_namespace(state)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local scratch = make_scratch()
  local line_lengths = {}
  for _, hunk in ipairs(extracted_hunks or {}) do
    -- Best-effort highlighting: skip failed hunks.
    pcall(apply_hunk, bufnr, scratch, ns, hunk, line_lengths, config or {})
  end
  wipe(scratch)
end

return M
