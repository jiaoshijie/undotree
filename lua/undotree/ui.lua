local diff = require('undotree.diff')
local default_mappings = {
  k = 'prev_star',
  j = 'next_star',
  Q = 'quit_undotree',
  q = 'quit_undotree_diff',
  K = 'prev_state',
  J = 'next_state',
  p = 'showOrFocusDiffWindow',
  ['<cr>'] = 'actionEnter',
}

local ui = {}
local set_bufAndWin_option = function(bufnr, winid)
  -- window options --
  vim.api.nvim_win_set_option(winid, 'number', false)
  vim.api.nvim_win_set_option(winid, 'relativenumber', false)
  vim.api.nvim_win_set_option(winid, 'winfixwidth', true)
  vim.api.nvim_win_set_option(winid, 'wrap', false)
  vim.api.nvim_win_set_option(winid, 'spell', false)
  vim.api.nvim_win_set_option(winid, 'cursorline', false)
  vim.api.nvim_win_set_option(winid, 'signcolumn', 'no')
  -- buf options --
  -- vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'delete')
  vim.api.nvim_buf_set_option(bufnr, 'buflisted', false)
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nowrite')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'undotree')
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

local create_split_window = function()
  if Jsj_undotree.bufnr ~= -1 and vim.fn.bufwinnr(Jsj_undotree.bufnr) ~= -1 then
    return
  end
  if Jsj_undotree.bufnr == -1 then
    Jsj_undotree.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(Jsj_undotree.bufnr, Jsj_undotree.undotreeName)
  end
  if Jsj_undotree.winid == -1 or Jsj_undotree.winid ~= vim.fn.bufwinid(Jsj_undotree.bufnr) then
    local screen_width = vim.api.nvim_get_option('columns')
    vim.cmd('silent keepalt topleft vertical ' .. tostring(math.floor(screen_width * 0.25)) .. ' new ' .. Jsj_undotree.undotreeName)
    Jsj_undotree.winid = vim.fn.bufwinid(Jsj_undotree.bufnr)
  end
  set_bufAndWin_option(Jsj_undotree.bufnr, Jsj_undotree.winid)
  local group = vim.api.nvim_create_augroup("undotreeQuit", {clear=true})
  vim.api.nvim_create_autocmd({"BufHidden"}, {callback=function()
    if Jsj_undotree.diffwinid ~= -1 then
      vim.api.nvim_win_close(Jsj_undotree.diffwinid, {force=true})
      Jsj_undotree.diffwinid = -1
    end
    if vim.fn.bufwinid(Jsj_undotree.diffbufnr_border) ~= -1 then
      vim.api.nvim_win_close(vim.fn.bufwinid(Jsj_undotree.diffbufnr_border), {force=true})
      Jsj_undotree.diffbufnr_border = -1
    end
  end, buffer=Jsj_undotree.bufnr, group=group})
end

ui.update_split_window = function()
  if vim.fn.bufwinnr(Jsj_undotree.bufnr) == -1 then
    create_split_window()
  end
  Jsj_undotree:graph2buf()
  for k, v in pairs(default_mappings) do
    vim.api.nvim_buf_set_keymap(Jsj_undotree.bufnr, 'n', k, "<cmd>lua require('undotree.actions')." .. v .. "()<cr>", {noremap=true, silent=true})
  end
end

local create_float_border = function(bufnr)
  local width = vim.api.nvim_get_option("columns") - vim.fn.winwidth(0)
  local height = vim.api.nvim_get_option("lines")
  -- size
  local win_height = math.ceil(height * 0.8 - 4)
  local win_width = math.ceil(width * 0.8)
  -- position
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = vim.fn.winwidth(0) + 4 -- math.ceil((width - win_width) / 2)
  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    zindex = 2,
  }
  local border_opts = {
    style = "minimal",
    relative = "editor",
    width = win_width + 2,
    height = win_height + 2,
    row = row - 1,
    col = col - 1,
    zindex = 1,
  }
  Jsj_undotree.diffbufnr_border = vim.api.nvim_create_buf(false, true)

  local border_lines = { '╭' .. string.rep('─', win_width) .. '╮' }
  local middle_line = '│' .. string.rep(' ', win_width) .. '│'
  local i = 0
  while i < win_height do
    table.insert(border_lines, middle_line)
    i = i + 1
  end
  table.insert(border_lines, '╰' .. string.rep('─', win_width) .. '╯')
  vim.api.nvim_buf_set_lines(Jsj_undotree.diffbufnr_border, 0, -1, false, border_lines)
  vim.api.nvim_buf_set_option(Jsj_undotree.diffbufnr_border, 'modifiable', false)

  if vim.fn.bufwinid(Jsj_undotree.diffbufnr_border) ~= -1 then
    vim.api.nvim_win_close(vim.fn.bufwinid(Jsj_undotree.diffbufnr_border), {force=true})
  end
  vim.api.nvim_open_win(Jsj_undotree.diffbufnr_border, false, border_opts)
  local winid = vim.api.nvim_open_win(bufnr, false, opts)

  local group = vim.api.nvim_create_augroup("undotreeQuitBorder", {clear=true})
  vim.api.nvim_create_autocmd({"BufHidden"}, {callback=function()
    -- vim.cmd('silent bwipeout! ' .. Jsj_undotree.diffbufnr_border)
    if vim.fn.bufwinid(Jsj_undotree.diffbufnr_border) ~= -1 then
      vim.api.nvim_win_close(vim.fn.bufwinid(Jsj_undotree.diffbufnr_border), {force=true})
      Jsj_undotree.diffbufnr_border = -1
    end
  end, buffer=bufnr, group=group})
  return winid
end

local create_float_window = function()
  if Jsj_undotree.diffbufnr == -1 then
    Jsj_undotree.diffbufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(Jsj_undotree.diffbufnr, Jsj_undotree.undotreeFloatName)
  end
  if Jsj_undotree.diffwinid == -1 or Jsj_undotree.diffwinid ~= vim.fn.bufwinid(Jsj_undotree.diffbufnr) then
    Jsj_undotree.diffwinid = create_float_border(Jsj_undotree.diffbufnr)
    Jsj_undotree.diffwinid = vim.fn.bufwinid(Jsj_undotree.diffbufnr)
  end
  set_bufAndWin_option(Jsj_undotree.diffbufnr, Jsj_undotree.diffwinid)
end

ui.update_diff_window = function()
  if vim.fn.bufwinnr(Jsj_undotree.diffbufnr) == -1 then
    create_float_window()
  end
  diff.update()
  if vim.fn.bufnr() ~= Jsj_undotree.bufnr then
    vim.cmd(string.format('silent exe "%s"', "norm! " .. vim.fn.bufwinnr(Jsj_undotree.bufnr) .. "\\<c-w>\\<c-w>"))
  end
end

return ui
