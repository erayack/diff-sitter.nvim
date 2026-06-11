local M = {}

local function normalize_path(path)
  if not path or path == "" or path == "/dev/null" then
    return nil
  end
  path = path:gsub("^a/", ""):gsub("^b/", "")
  return path
end

local function new_file(old_path, new_path)
  local file = { old_path = normalize_path(old_path), new_path = normalize_path(new_path), hunks = {} }
  return file
end

local function finish_hunk(hunk, end_row)
  if hunk and not hunk.body_end_row then
    hunk.body_end_row = end_row
  end
end

function M.parse_lines(lines)
  local files = {}
  local current_file = nil
  local current_hunk = nil

  for i, line in ipairs(lines) do
    local row = i - 1
    local a, b = line:match("^diff %-%-git%s+([^%s]+)%s+([^%s]+)")
    if a or b then
      finish_hunk(current_hunk, row)
      current_file = new_file(a, b)
      table.insert(files, current_file)
      current_hunk = nil
    elseif line:match("^@@") then
      finish_hunk(current_hunk, row)
      if not current_file then
        current_file = new_file(nil, nil)
        table.insert(files, current_file)
      end
      current_hunk = {
        file = current_file,
        header_row = row,
        body_start_row = row + 1,
        body_end_row = nil,
      }
      table.insert(current_file.hunks, current_hunk)
    elseif not current_hunk and line:match("^%-%-%-%s+") then
      local path = line:match("^%-%-%-%s+([^%s]+)")
      if not current_file then
        current_file = new_file(path, nil)
        table.insert(files, current_file)
      else
        current_file.old_path = normalize_path(path)
      end
    elseif not current_hunk and line:match("^%+%+%+%s+") then
      local path = line:match("^%+%+%+%s+([^%s]+)")
      if not current_file then
        current_file = new_file(nil, path)
        table.insert(files, current_file)
      else
        current_file.new_path = normalize_path(path)
      end
    end
  end

  finish_hunk(current_hunk, #lines)
  return files
end

function M.parse(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return M.parse_lines(lines)
end

return M
