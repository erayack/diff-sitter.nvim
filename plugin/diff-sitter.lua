if vim.g.loaded_diff_sitter == 1 then
  return
end
vim.g.loaded_diff_sitter = 1

require("diff-sitter").setup()
