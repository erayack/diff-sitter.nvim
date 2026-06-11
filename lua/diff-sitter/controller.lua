local diff_parser = require("diff-sitter.diff_parser")
local language = require("diff-sitter.language")
local extractor = require("diff-sitter.extractor")
local highlighter = require("diff-sitter.highlighter")

local M = {}

local states = {}
local namespace = vim.api.nvim_create_namespace("diff-sitter")

local function normalize_bufnr(bufnr)
  return bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
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

function M.refresh(bufnr, config)
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

  local files = diff_parser.parse(bufnr)
  for _, file in ipairs(files) do
    file.lang = language.detect(file.new_path or file.old_path)
  end

  local extracted = extractor.extract(bufnr, files, config or {})
  highlighter.apply(bufnr, extracted, state, config or {})
end

function M.schedule_refresh(bufnr, config)
  bufnr = normalize_bufnr(bufnr)
  local state = states[bufnr]
  if not state then
    return
  end
  cancel_timer(state)

  local delay = (config and config.debounce_ms) or 100
  local timer = vim.loop.new_timer()
  state.pending_timer = timer
  timer:start(delay, 0, vim.schedule_wrap(function()
    if states[bufnr] == state then
      state.pending_timer = nil
      pcall(function()
        timer:close()
      end)
      M.refresh(bufnr, config)
    else
      pcall(function()
        timer:close()
      end)
    end
  end))
end

function M.attach(bufnr, config)
  bufnr = normalize_bufnr(bufnr)
  if not valid(bufnr) then
    return
  end

  if states[bufnr] then
    states[bufnr].enabled = true
    M.schedule_refresh(bufnr, config)
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
      M.schedule_refresh(args.buf, config)
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = state.augroup,
    buffer = bufnr,
    callback = function(args)
      M.detach(args.buf)
    end,
  })

  M.schedule_refresh(bufnr, config)
end

function M.detach(bufnr)
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

function M.is_enabled(bufnr)
  bufnr = normalize_bufnr(bufnr)
  return states[bufnr] ~= nil and states[bufnr].enabled == true
end

function M._states()
  return states
end

return M
