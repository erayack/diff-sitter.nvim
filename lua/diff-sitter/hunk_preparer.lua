local M = {}

local parser_cache = {}
local language_cache = {}

local extension_map = {
  rs = "rust",
  go = "go",
  js = "javascript",
  jsx = "javascript",
  ts = "typescript",
  tsx = "tsx",
  py = "python",
  lua = "lua",
  c = "c",
  h = "c",
  cpp = "cpp",
  cxx = "cpp",
  cc = "cpp",
  hpp = "cpp",
  java = "java",
  rb = "ruby",
  php = "php",
  sh = "bash",
  bash = "bash",
  zsh = "bash",
  md = "markdown",
}

local function normalize_bufnr(bufnr)
  return bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
end

local function normalize_path(path)
  if not path or path == "" or path == "/dev/null" then
    return nil
  end
  return path:gsub("^a/", ""):gsub("^b/", "")
end

local function parse_path_token(text, start_index)
  local index = start_index or 1
  while index <= #text and text:sub(index, index):match("%s") do
    index = index + 1
  end

  if index > #text then
    return nil, nil
  end

  if text:sub(index, index) ~= '"' then
    local token_start = index
    while index <= #text and not text:sub(index, index):match("%s") do
      index = index + 1
    end
    return text:sub(token_start, index - 1), index
  end

  index = index + 1
  local parts = {}
  while index <= #text do
    local char = text:sub(index, index)
    if char == '"' then
      return table.concat(parts), index + 1
    end
    if char == "\\" and index < #text then
      local next_char = text:sub(index + 1, index + 1)
      if next_char == '"' or next_char == "\\" then
        table.insert(parts, next_char)
        index = index + 2
      else
        table.insert(parts, char)
        index = index + 1
      end
    else
      table.insert(parts, char)
      index = index + 1
    end
  end

  return nil, nil
end

local function parse_diff_git_paths(line)
  local _, after_prefix = line:find("^diff %-%-git%s+")
  if not after_prefix then
    return nil, nil
  end

  local old_path, next_index = parse_path_token(line, after_prefix + 1)
  if not old_path then
    return nil, nil
  end

  local new_path = parse_path_token(line, next_index)
  if not new_path then
    return nil, nil
  end

  return old_path, new_path
end

local function parse_file_header_path(line, marker)
  local _, after_prefix = line:find("^" .. vim.pesc(marker) .. "%s+")
  if not after_prefix then
    return nil
  end

  local path = parse_path_token(line, after_prefix + 1)
  return path
end

local function new_file(old_path, new_path)
  return { old_path = normalize_path(old_path), new_path = normalize_path(new_path), hunks = {} }
end

local function finish_hunk(hunk, end_row)
  if hunk and not hunk.body_end_row then
    hunk.body_end_row = end_row
  end
end

local function parse_lines(lines)
  local files = {}
  local current_file = nil
  local current_hunk = nil

  for i, line in ipairs(lines) do
    local row = i - 1
    local a, b = parse_diff_git_paths(line)
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
      local path = parse_file_header_path(line, "---")
      if not current_file then
        current_file = new_file(path, nil)
        table.insert(files, current_file)
      else
        current_file.old_path = normalize_path(path)
      end
    elseif not current_hunk and line:match("^%+%+%+%s+") then
      local path = parse_file_header_path(line, "+++")
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

local function extension(path)
  return path and path:match("%.([%w_%-]+)$") or nil
end

local function has_parser(lang)
  if not lang or lang == "" then
    return false
  end
  if parser_cache[lang] ~= nil then
    return parser_cache[lang]
  end
  local ok
  if vim.treesitter and vim.treesitter.language and vim.treesitter.language.add then
    ok = pcall(vim.treesitter.language.add, lang)
  else
    ok = pcall(vim.treesitter.get_string_parser, "", lang)
  end
  parser_cache[lang] = ok == true
  return parser_cache[lang]
end

local function detect_language(path)
  if not path or path == "" then
    return nil
  end
  if language_cache[path] ~= nil then
    return language_cache[path] or nil
  end

  local ft
  pcall(function()
    ft = vim.filetype.match({ filename = path })
  end)

  local candidates = {}
  if ft and ft ~= "" then
    local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
    if ok and lang then
      table.insert(candidates, lang)
    end
    table.insert(candidates, ft)
  end

  local ext = extension(path)
  if ext and extension_map[ext] then
    table.insert(candidates, extension_map[ext])
  end

  local seen = {}
  for _, lang in ipairs(candidates) do
    if not seen[lang] then
      seen[lang] = true
      if has_parser(lang) then
        language_cache[path] = lang
        return lang
      end
    end
  end

  language_cache[path] = false
  return nil
end

local function kind_for_prefix(prefix)
  if prefix == "+" then
    return "add"
  elseif prefix == "-" then
    return "delete"
  elseif prefix == " " then
    return "context"
  end
end

local function prepare_hunk(bufnr, hunk, lang, lines, config)
  local line_count = hunk.body_end_row - hunk.body_start_row
  if config and config.max_hunk_lines and line_count > config.max_hunk_lines then
    return nil
  end

  local code_lines = {}
  local row_map = {}

  for row = hunk.body_start_row, hunk.body_end_row - 1 do
    local line = lines[row + 1] or ""
    if not line:match("^\\ No newline at end of file") then
      local kind = kind_for_prefix(line:sub(1, 1))
      if kind then
        table.insert(code_lines, line:sub(2))
        row_map[#code_lines - 1] = {
          source_row = row,
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
    lang = lang,
    source_bufnr = bufnr,
    source_start_row = hunk.body_start_row,
    source_end_row = hunk.body_end_row,
    code_lines = code_lines,
    row_map = row_map,
  }
end

function M.prepare_lines(bufnr, lines, config)
  local extracted = {}
  for _, file in ipairs(parse_lines(lines)) do
    local lang = detect_language(file.new_path or file.old_path)
    if lang then
      for _, hunk in ipairs(file.hunks) do
        local item = prepare_hunk(bufnr, hunk, lang, lines, config or {})
        if item then
          table.insert(extracted, item)
        end
      end
    end
  end
  return extracted
end

function M.prepare(bufnr, config)
  bufnr = normalize_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return M.prepare_lines(bufnr, lines, config)
end

function M._has_parser(lang)
  return has_parser(lang)
end

return M
