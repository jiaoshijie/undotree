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
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(bufnr, 'buflisted', false)
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nowrite')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'undotree')
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

ui.create_split_window = function(jsj_undotree)
  if jsj_undotree.bufnr ~= -1 and vim.fn.bufwinnr(jsj_undotree.bufnr) ~= -1 then
    return
  end
  local winid = vim.fn.bufwinid(jsj_undotree.bufnr)
  if winid == -1 then
    jsj_undotree.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(jsj_undotree.bufnr, jsj_undotree.undotreeName)
    local screen_width = vim.api.nvim_get_option('columns')
    vim.cmd('silent keepalt topleft vertical ' .. tostring(math.floor(screen_width * 0.25)) .. ' new ' .. jsj_undotree.undotreeName)
    winid = vim.fn.bufwinid(jsj_undotree.bufnr)
  end
  set_bufAndWin_option(jsj_undotree.bufnr, winid)
  local group = vim.api.nvim_create_augroup("undotree_buf", {clear=true})
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer=jsj_undotree.bufnr,
    callback=function()
      ui.quit_diff_win(jsj_undotree)
      jsj_undotree:clear()
  end})
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    buffer = jsj_undotree.bufnr,
    callback = function()
      ui.quit_diff_win(jsj_undotree)
  end})
end

local create_float_border = function(jsj_undotree)
  local bufnr = jsj_undotree.diffbufnr
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
  jsj_undotree.diffbufnr_border = vim.api.nvim_create_buf(false, true)

  local border_lines = { '╭' .. string.rep('─', win_width) .. '╮' }
  local middle_line = '│' .. string.rep(' ', win_width) .. '│'
  local i = 0
  while i < win_height do
    table.insert(border_lines, middle_line)
    i = i + 1
  end
  table.insert(border_lines, '╰' .. string.rep('─', win_width) .. '╯')
  vim.api.nvim_buf_set_lines(jsj_undotree.diffbufnr_border, 0, -1, false, border_lines)
  vim.api.nvim_buf_set_option(jsj_undotree.diffbufnr_border, 'modifiable', false)

  local diff_border_winid = vim.api.nvim_open_win(jsj_undotree.diffbufnr_border, false, border_opts)
  local diffwinid = vim.api.nvim_open_win(bufnr, false, opts)

  local group = vim.api.nvim_create_augroup("undotreeQuitBorder", {clear=true})
  vim.api.nvim_create_autocmd({"BufWipeout"}, {callback=function()
    if vim.fn.bufwinid(jsj_undotree.diffbufnr_border) ~= -1 then
      vim.api.nvim_win_close(vim.fn.bufwinid(jsj_undotree.diffbufnr_border), {force=true})
      jsj_undotree.diffbufnr_border = -1
    end
  end, buffer=bufnr, group=group})
  return diffwinid, diff_border_winid
end

ui.create_float_window = function(jsj_undotree)
  if jsj_undotree.diffbufnr == -1 then
    jsj_undotree.diffbufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(jsj_undotree.diffbufnr, jsj_undotree.undotreeFloatName)
  end
  local diffwinid = vim.fn.bufwinid(jsj_undotree.diffbufnr)
  local diff_border_winid = nil
  if diffwinid == -1 then
    local ev_bak = vim.opt.eventignore:get()
    vim.opt.eventignore = { "BufEnter","BufLeave","BufWinLeave","InsertLeave","CursorMoved","BufWritePost" }
    diffwinid, diff_border_winid = create_float_border(jsj_undotree)
    vim.opt.eventignore = ev_bak
  end
  set_bufAndWin_option(jsj_undotree.diffbufnr, diffwinid)
  set_bufAndWin_option(jsj_undotree.diffbufnr_border, diff_border_winid)
end

ui.quit_undotree_split = function(jsj_undotree)
  jsj_undotree.targetbufnr = -1
  local winid = vim.fn.bufwinid(jsj_undotree.bufnr)
  if winid ~= -1 then
    jsj_undotree.bufnr = -1
    vim.api.nvim_win_close(winid, {force=true})
  end
end

ui.quit_diff_win = function(jsj_undotree)
  local diffwinid = vim.fn.bufwinid(jsj_undotree.diffbufnr)
  if diffwinid ~= -1 then
    jsj_undotree.diffbufnr = -1
    vim.api.nvim_win_close(diffwinid, {force=true})
  end
  diffwinid = vim.fn.bufwinid(jsj_undotree.diffbufnr_border)
  if diffwinid ~= -1 then
    jsj_undotree.diffbufnr_border = -1
    vim.api.nvim_win_close(diffwinid, {force=true})
  end
end

return ui
