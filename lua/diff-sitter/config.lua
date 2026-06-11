local M = {}

M.defaults = {
  enabled = true,
  filetypes = { "diff", "patch", "gitcommit" },
  debounce_ms = 100,
  max_hunk_lines = 400,
  max_buffer_lines = 20000,
  debug = false,
}

function M.merge(opts)
  opts = opts or {}
  local config = vim.deepcopy(M.defaults)
  config = vim.tbl_deep_extend("force", config, opts)
  return config
end

return M
