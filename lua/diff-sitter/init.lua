local config_mod = require("diff-sitter.config")
local hunk_preparer = require("diff-sitter.hunk_preparer")
local highlighter = require("diff-sitter.highlighter")

local M = {}

local config = config_mod.merge()
local setup_done = false
local augroup = nil
local states = {}
local namespace = vim.api.nvim_create_namespace("diff-sitter")

local function normalize_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function valid(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

local function cancel_timer(state)
  if state and state.pending_timer then
    state.pending_timer:stop()
    state.pending_timer:close()
    state.pending_timer = nil
  end
end

local function clear(bufnr, state)
  if valid(bufnr) and state and state.ns then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, state.ns, 0, -1)
  end
end

local function delete_augroup(state)
  if state and state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    state.augroup = nil
  end
end

local function refresh(bufnr)
  bufnr = normalize_bufnr(bufnr)
  local state = states[bufnr]
  if not state or not valid(bufnr) then
    return
  end

  state.last_changedtick = vim.api.nvim_buf_get_changedtick(bufnr)

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if config and config.max_buffer_lines and line_count > config.max_buffer_lines then
    clear(bufnr, state)
    return
  end

  highlighter.apply(bufnr, hunk_preparer.prepare(bufnr, config or {}), state, config or {})
end

local function schedule_refresh(bufnr)
  bufnr = normalize_bufnr(bufnr)
  local state = states[bufnr]
  if not state then
    return
  end
  cancel_timer(state)

  local timer = vim.loop.new_timer()
  state.pending_timer = timer
  timer:start(
    config.debounce_ms or 100,
    0,
    vim.schedule_wrap(function()
      if states[bufnr] == state then
        state.pending_timer = nil
        pcall(function()
          timer:close()
        end)
        refresh(bufnr)
      else
        pcall(function()
          timer:close()
        end)
      end
    end)
  )
end

local function attach(bufnr)
  bufnr = normalize_bufnr(bufnr)
  if not valid(bufnr) then
    return
  end

  if states[bufnr] then
    states[bufnr].enabled = true
    schedule_refresh(bufnr)
    return
  end

  local state = {
    enabled = true,
    ns = namespace,
    augroup = vim.api.nvim_create_augroup("DiffSitterBuffer" .. bufnr, { clear = true }),
    pending_timer = nil,
    last_changedtick = nil,
  }
  states[bufnr] = state

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
    group = state.augroup,
    buffer = bufnr,
    callback = function(args)
      schedule_refresh(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = state.augroup,
    buffer = bufnr,
    callback = function(args)
      M.disable(args.buf)
    end,
  })

  schedule_refresh(bufnr)
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
  attach(normalize_bufnr(bufnr))
end

function M.disable(bufnr)
  bufnr = normalize_bufnr(bufnr)
  local state = states[bufnr]
  if not state then
    return
  end
  cancel_timer(state)
  clear(bufnr, state)
  delete_augroup(state)
  states[bufnr] = nil
end

function M.refresh(bufnr)
  refresh(normalize_bufnr(bufnr))
end

function M.is_enabled(bufnr)
  bufnr = normalize_bufnr(bufnr)
  return states[bufnr] ~= nil and states[bufnr].enabled == true
end

function M._config()
  return config
end

function M._states()
  return states
end

return M
