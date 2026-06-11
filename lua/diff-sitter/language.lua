local M = {}

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

local function extension(path)
  return path and path:match("%.([%w_%-]+)$") or nil
end

function M.has_parser(lang)
  if not lang or lang == "" then
    return false
  end
  if vim.treesitter and vim.treesitter.language and vim.treesitter.language.add then
    local ok = pcall(vim.treesitter.language.add, lang)
    return ok
  end
  local ok = pcall(vim.treesitter.get_string_parser, "", lang)
  return ok
end

function M.detect(path)
  if not path or path == "" then
    return nil
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
      if M.has_parser(lang) then
        return lang
      end
    end
  end

  return nil
end

return M
