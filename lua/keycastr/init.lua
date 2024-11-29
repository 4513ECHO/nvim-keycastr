---@diagnostic disable: duplicate-doc-alias, duplicate-doc-field
---@alias keycastr.state { bufnr: integer, buf_length: integer, winid: integer|nil }
---@class keycastr.config
---@field ignore_mouse boolean
---@field win_config vim.api.keyset.win_config
---@field position "NE"|"NW"|"SE"|"SW

local M = {}
local ns = vim.api.nvim_create_namespace "keycastr"
---@type keycastr.config
local default_config = {
  ignore_mouse = true,
  win_config = {
    width = 50,
    height = 1,
  },
  position = "SE",
}
---@type keycastr.config
local current_config = vim.deepcopy(default_config)
---@type keycastr.state|nil
local state

---@param position "NE"|"NW"|"SE"|"SW"
---@return vim.api.keyset.win_config
local function get_position(position)
  if position == "NE" then
    return { anchor = "NE", row = 0, col = vim.o.columns }
  elseif position == "NW" then
    return { anchor = "NW", row = 0, col = 0 }
  elseif position == "SE" then
    return {
      anchor = "SE",
      row = vim.o.lines - vim.o.cmdheight - 1,
      col = vim.o.columns,
    }
  elseif position == "SW" then
    return { anchor = "SW", row = vim.o.lines - vim.o.cmdheight - 1, col = 0 }
  end
  error("[keycastr] Invalid anchor value: " .. position)
end

---@param config keycastr.config
---@return vim.api.keyset.win_config
local function config_to_open_win(config)
  return vim.tbl_deep_extend("force", {
    relative = "editor",
    focusable = false,
    style = "minimal",
  }, get_position(config.position), config.win_config)
end

---@param key string
local function draw(key)
  if not state then
    return
  end
  local config = M.config.get()
  state.buf_length = state.buf_length + #key
  -- NOTE: Error may occur due to textlock
  pcall(vim.api.nvim_buf_set_text, state.bufnr, -1, -1, -1, -1, { key })
  if state.winid and state.buf_length > config.win_config.width then
    local leftcol = state.buf_length - config.win_config.width
    vim.api.nvim_win_call(
      state.winid,
      function() vim.fn.winrestview { leftcol = leftcol } end
    )
  end
  -- NOTE: Screen update is needed in command-line mode
  if vim.api.nvim_get_mode().mode == "c" then
    vim.cmd.redraw()
  end
end

local mouse_keys = {
  "Mouse>",
  "Drag>",
  "Release>",
  "WheelUp>",
  "WheelDown>",
  "WheelLeft>",
  "WheelRight>",
}

M.config = {
  ---@return keycastr.config
  get = function() return current_config end,
  ---@param user_config keycastr.config
  set = function(user_config)
    current_config =
      vim.tbl_deep_extend("force", default_config, current_config, user_config)
    if state and state.winid then
      vim.api.nvim_win_set_config(
        state.winid,
        config_to_open_win(current_config)
      )
    end
  end,
}

function M.enable()
  if not M.show() then
    return
  end
  local ignore_mouse = M.config.get().ignore_mouse

  vim.on_key(function(_, typed)
    local key = vim.fn.keytrans(typed)
    if
      ignore_mouse
      and vim.iter(mouse_keys):any(function(v) return vim.endswith(key, v) end)
    then
      return
    end
    draw(key)
  end, ns)
end

---@return boolean #whether the window is newly opened
function M.show()
  if state and state.winid then
    return false
  end
  local config = M.config.get()
  local bufnr = state and state.bufnr or vim.api.nvim_create_buf(false, true)
  local winid = vim.api.nvim_open_win(bufnr, false, config_to_open_win(config))
  vim.api.nvim_set_option_value("cursorline", false, { win = winid })
  vim.api.nvim_set_option_value("wrap", false, { win = winid })
  if state then
    state.winid = winid
  else
    state = { bufnr = bufnr, buf_length = 0, winid = winid }
  end
  return true
end

function M.disable()
  if state then
    M.hide()
    vim.api.nvim_buf_delete(state.bufnr, {})
    state = nil
    vim.on_key(nil, ns)
  end
end

function M.hide()
  if state and state.winid then
    vim.api.nvim_win_close(state.winid, true)
    state.winid = nil
  end
end

return M
