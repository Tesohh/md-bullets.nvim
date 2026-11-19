local M = {}

local api = vim.api

local NAMESPACE = api.nvim_create_namespace("md-bullets")

local defaults = {
  -- Bullet characters, cycled by heading level
  -- Can also be a function that receives the default list and returns a list
  bullets = { "◉", "○", "✸", "✿" },
  -- true always draws the bullet; false shows the raw '#' markers when the
  -- cursor is on them
  concealcursor = false,
}

local config = {}

---Merge the user config with the defaults
---@param user_config? MdBulletsConfig
local function set_config(user_config)
  user_config = user_config or {}
  local bullets = vim.tbl_get(user_config, "bullets")
  if type(bullets) == "function" then
    user_config.bullets = bullets(defaults.bullets) or defaults.bullets
  end
  config = vim.tbl_deep_extend("keep", user_config, defaults)
end

---@class MdBulletsConfig
---@field bullets? string[] | string[][] | function(defaults: string[]): string[]
---@field concealcursor? boolean

---Resolve the bullet for a heading level, cycling through the list
---@param level integer
---@param config MdBulletsConfig
---@return string symbol
---@return string? highlight
local function symbol_for_level(level, config)
  local bullets = config.bullets
  if type(bullets) ~= "table" or #bullets == 0 then
    vim.notify_once("md-bullets: 'bullets' config is empty", vim.log.levels.WARN, { title = "md-bullets" })
    return "", nil
  end

  local index = level
  if level > #bullets then
    index = ((level - 1) % #bullets) + 1
  end

  local symbol = bullets[index]
  local highlight = "MdBulletsBullet" .. ((index - 1) % #bullets) + 1
  if type(symbol) == "table" then
    highlight = symbol[2] or highlight
    symbol = symbol[1]
  end
  if type(symbol) ~= "string" then
    return "", nil
  end
  return symbol, highlight
end

---Return the heading level of a line, or nil when it is not a heading
---@param line string?
---@return integer? level
local function heading_level(line)
  if not line then
    return nil
  end
  local markers = line:match("^(#+)%s")
  if not markers then
    return nil
  end
  return #markers
end

---Width of the inline virtual text another plugin (md-indent) put at the
---start of a line. Our marks must shift right by that amount to stay on the
---'#' glyphs.
---@param bufnr integer
---@param lnum integer 0-based row
---@return integer
local function line_offset(bufnr, lnum)
  local ns = api.nvim_get_namespaces()["md-indent"]
  if not ns then
    return 0
  end
  local ok, marks = pcall(api.nvim_buf_get_extmarks, bufnr, ns, { lnum, 0 }, { lnum, -1 }, { details = true })
  if not ok or type(marks) ~= "table" or #marks == 0 then
    return 0
  end
  local width = 0
  for _, mark in ipairs(marks) do
    for _, chunk in ipairs(mark[4].virt_text or {}) do
      width = width + vim.fn.strdisplaywidth(chunk[1])
    end
  end
  return width
end

---Hide the leading '#' markers and draw the bullet over the last one.
---Marks are pinned to fixed window columns so they land on the '#' glyphs
---regardless of inline virtual text other plugins add at column 0.
---@param bufnr integer
---@param lnum integer 0-based row
---@param level integer
local function set_mark(bufnr, lnum, level)
  local symbol, highlight = symbol_for_level(level, config)
  if symbol == "" then
    return
  end

  local offset = line_offset(bufnr, lnum)
  -- cover every leading '#' with a one-cell space
  for col = 0, level - 2 do
    pcall(api.nvim_buf_set_extmark, bufnr, NAMESPACE, lnum, 0, {
      virt_text = { { " ", highlight } },
      virt_text_pos = "overlay",
      virt_text_win_col = offset + col,
      hl_mode = "replace",
      ephemeral = true,
    })
  end
  -- bullet goes on the last '#'
  pcall(api.nvim_buf_set_extmark, bufnr, NAMESPACE, lnum, 0, {
    virt_text = { { symbol, highlight } },
    virt_text_pos = "overlay",
    virt_text_win_col = offset + level - 1,
    hl_mode = "replace",
    ephemeral = true,
  })
end

---Check if a line is inside a fenced code block
---@param lnum integer 0-based row
---@return boolean
local function in_code_block(bufnr, lnum)
  local fence = nil
  for i = 0, lnum - 1 do
    local line = api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    -- opening fences may carry an info string, closing ones do not
    local current = line:match("^(```+)") or line:match("^(~~~+)")
    if current then
      if not fence then
        fence = current:sub(1, 3)
      elseif current:sub(1, 3) == fence then
        fence = nil
      end
    end
  end
  return fence ~= nil
end

---Whether a heading line should be drawn with its bullet. With
---'concealcursor' off, the raw markers only show while the cursor is on one
---of the '#' glyphs.
---@param winid integer
---@param row integer 0-based row
---@param level integer
---@return boolean
local function should_conceal(winid, row, level)
  if config.concealcursor then
    return true
  end
  local cursor = api.nvim_win_get_cursor(winid)
  if cursor[1] - 1 ~= row then
    return true
  end
  return cursor[2] >= level
end

---Draw bullets for all heading lines in a row range
---@param bufnr integer
---@param winid integer
---@param start_row integer 0-based, inclusive
---@param end_row integer 0-based, inclusive, extra rows yield no lines
local function draw(bufnr, winid, start_row, end_row)
  for row = start_row, end_row do
    local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local level = heading_level(line)
    if level and should_conceal(winid, row, level) then
      if not in_code_block(bufnr, row) then
        set_mark(bufnr, row, level)
      end
    end
  end
end

local last_cursor = {}

---Redraw the old and new cursor lines so the raw markers come back or hide.
---Cursor moves alone do not invalidate the window, so nothing else triggers it.
---@param winid integer
local function on_cursor_moved(winid)
  if config.concealcursor then
    -- marks never depend on the cursor in this mode
    return
  end
  local bufnr = api.nvim_win_get_buf(winid)
  if vim.bo[bufnr].filetype ~= "markdown" then
    return
  end
  local cursor = api.nvim_win_get_cursor(winid)
  local row = cursor[1] - 1
  local col = cursor[2]
  local prev = last_cursor[winid]
  last_cursor[winid] = { row, col }
  if api.nvim__redraw then
    if prev == nil then
      -- no known previous position, repaint the whole window once
      api.nvim__redraw({ win = winid, valid = false, flush = true })
    elseif prev[1] ~= row or prev[2] ~= col then
      -- column moves matter too: the marker block hides or shows per column
      api.nvim__redraw({
        buf = bufnr,
        range = { math.min(prev[1], row), math.max(prev[1], row) + 1 },
        flush = true,
      })
    end
  else
    vim.schedule(function()
      vim.cmd("redraw")
    end)
  end
end

---Set up highlights and the decoration provider
---@param user_config? MdBulletsConfig
function M.setup(user_config)
  set_config(user_config)

  for i, _ in ipairs(type(config.bullets) == "table" and config.bullets or {}) do
    if type(config.bullets[i]) == "table" and config.bullets[i][2] then
      -- custom highlight from the config, nothing to define
    elseif vim.fn.hlexists("@markup.heading." .. i .. ".markdown") == 1 then
      api.nvim_set_hl(0, "MdBulletsBullet" .. i, { link = "@markup.heading." .. i .. ".markdown", default = true })
    elseif vim.fn.hlexists("@markup.heading") == 1 then
      api.nvim_set_hl(0, "MdBulletsBullet" .. i, { link = "@markup.heading", default = true })
    else
      api.nvim_set_hl(0, "MdBulletsBullet" .. i, { link = "Title", default = true })
    end
  end

  api.nvim_set_decoration_provider(NAMESPACE, {
    on_win = function(_, winid, bufnr, topline, botline)
      if vim.bo[bufnr].filetype ~= "markdown" then
        return false
      end
      draw(bufnr, winid, topline, botline)
    end,
    on_line = function(_, winid, bufnr, row)
      if vim.bo[bufnr].filetype ~= "markdown" then
        return
      end
      local level = heading_level(api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1])
      if level and should_conceal(winid, row, level) and not in_code_block(bufnr, row) then
        set_mark(bufnr, row, level)
      end
    end,
  })

  local group = api.nvim_create_augroup("md-bullets", { clear = true })
  api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      on_cursor_moved(api.nvim_get_current_win())
    end,
  })
  api.nvim_create_autocmd({ "VimEnter", "WinEnter", "BufWinEnter" }, {
    group = group,
    callback = function()
      local winid = api.nvim_get_current_win()
      local cursor = api.nvim_win_get_cursor(winid)
      last_cursor[winid] = { cursor[1] - 1, cursor[2] }
    end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      last_cursor[tonumber(ev.match)] = nil
    end,
  })
end

return M
