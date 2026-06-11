local config_mod = require("diff-sitter.config")
local controller = require("diff-sitter.controller")

local M = {}

local config = config_mod.merge()
local setup_done = false
local augroup = nil

local function normalize_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function create_commands()
  vim.api.nvim_create_user_command("DiffSitterEnable", function()
    M.enable(0)
  end, { force = true })
  vim.api.nvim_create_user_command("DiffSitterDisable", function()
    M.disable(0)
  end, { force = true })
  vim.api.nvim_create_user_command("DiffSitterRefresh", function()
    M.refresh(0)
  end, { force = true })
end

local function create_autocmds()
  if augroup then
    vim.api.nvim_del_augroup_by_id(augroup)
  end
  augroup = vim.api.nvim_create_augroup("DiffSitter", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = config.filetypes,
    callback = function(args)
      if config.enabled then
        M.enable(args.buf)
      end
    end,
  })
end

function M.setup(opts)
  config = config_mod.merge(opts)
  create_commands()
  create_autocmds()
  setup_done = true
  return config
end

function M.enable(bufnr)
  if not setup_done then
    M.setup()
  end
  controller.attach(normalize_bufnr(bufnr), config)
end

function M.disable(bufnr)
  controller.detach(normalize_bufnr(bufnr))
end

function M.refresh(bufnr)
  controller.refresh(normalize_bufnr(bufnr), config)
end

function M.is_enabled(bufnr)
  return controller.is_enabled(normalize_bufnr(bufnr))
end

function M._config()
  return config
end

return M
