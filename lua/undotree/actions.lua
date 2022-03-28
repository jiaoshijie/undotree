local actions = {}
local update_diff = require('undotree.diff').update_diff
local ui = require('undotree.ui')

local jump2star = function(direction)
  local lnum = vim.fn.line('.')
  while lnum > vim.fn.line('^') and lnum <= vim.fn.line('$') do
    lnum = lnum + direction
    local col = actions.findStar(lnum)
    if col then
      vim.fn.cursor({lnum, col})
      break
    end
  end
end

local setTargetFocus = function(jsj_undotree)
  local winnr = vim.fn.bufwinnr(jsj_undotree.targetbufnr)
  if winnr == -1 then return false end
  vim.cmd(string.format('silent exe "%s"', "norm! " .. winnr .. "\\<c-w>\\<c-w>"))
  return true
end

local actionInTarget = function(jsj_undotree, cmd)
  local ev_bak = vim.opt.eventignore:get()
  vim.opt.eventignore = { "BufEnter","BufLeave","BufWinLeave","InsertLeave","CursorMoved","BufWritePost" }
  if not setTargetFocus(jsj_undotree) then return end
  vim.cmd(cmd)
  actions.setFocus()
  vim.opt.eventignore = ev_bak
end

actions.findStar = function(lnum)
  local line = vim.fn.getline(lnum)
  local i = 1
  while i <= #line do
    if string.sub(line, i, i) == '*' then
      return i
    end
    i = i + 1
  end
  return nil
end

actions.setFocus = function(jsj_undotree)
  if vim.fn.bufnr() == jsj_undotree.bufnr then return end
  local winnr = vim.fn.bufwinnr(jsj_undotree.bufnr)
  if winnr == -1 then return end
  vim.cmd(string.format('silent exe "%s"', "norm! " .. winnr .. "\\<c-w>\\<c-w>"))
end

actions.prev_star = function(jsj_undotree)
  jump2star(-1)
  update_diff(jsj_undotree)
end

actions.next_star = function(jsj_undotree)
  jump2star(1)
  update_diff(jsj_undotree)
end

actions.prev_state = function(jsj_undotree)
  jump2star(-1)
  actions.actionEnter(jsj_undotree)
end

actions.next_state = function(jsj_undotree)
  jump2star(1)
  actions.actionEnter(jsj_undotree)
end

actions.quit_undotree = function(jsj_undotree)
  ui.quit_diff_win(jsj_undotree)
  ui.quit_undotree_split(jsj_undotree)
  jsj_undotree:clear()
end

actions.quit_diff_win = function(jsj_undotree)
  ui.quit_diff_win(jsj_undotree)
end

actions.undo2 = function(jsj_undotree, cseq)
  if cseq == 0 then
    actionInTarget(string.format('silent exe "%s"', 'norm! ' .. jsj_undotree.seq_last .. 'u'))
    return
  end
  actionInTarget(string.format('silent exe "%s"', 'undo ' .. cseq))
end

actions.actionEnter = function(jsj_undotree)
  local info = jsj_undotree.asciimeta[#jsj_undotree.charGraph - vim.fn.line('.') + 1]
  if info == nil then
    return
  end
  actions.undo2(info.seq)
  jsj_undotree:setMark(info.seq, vim.fn.line('.'))
  jsj_undotree.seq_cur = info.seq
  update_diff()
end

actions.showOrFocusDiffWindow = function(jsj_undotree)
  local winnr = vim.fn.bufwinnr(jsj_undotree.diffbufnr)
  if winnr == -1 then
    update_diff()
  else
    local ev_bak = vim.opt.eventignore:get()
    vim.opt.eventignore = { "BufEnter","BufLeave","BufWinLeave","InsertLeave","CursorMoved","BufWritePost" }
    vim.cmd(string.format('silent exe "%s"', "norm! " .. winnr .. "\\<c-w>\\<c-w>"))
    vim.opt.eventignore = ev_bak
  end
end

actions.create_undo_window = function(jsj_undotree)
  ui.create_split_window(jsj_undotree)
end

return actions
