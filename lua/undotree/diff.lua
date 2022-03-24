local diff = {}
local create_float_window = require("undotree.ui").create_float_window

-- NOTICE: it different from undotree.actions
local undo2 = function(cseq)
  if cseq == 0 then
    vim.cmd(string.format('silent exe "%s"', 'norm! ' .. Jsj_undotree.seq_last .. 'u'))
    return
  end
  vim.cmd(string.format('silent exe "%s"', 'undo ' .. cseq))
end

local parseDiffInfo = function(diff_lines, old_seq, new_seq)
  if vim.fn.bufnr() ~= Jsj_undotree.diffbufnr then
    vim.cmd(string.format('silent exe "%s"', "norm! " .. vim.fn.bufwinnr(Jsj_undotree.diffbufnr) .. "\\<c-w>\\<c-w>"))
  end
  vim.api.nvim_buf_set_option(Jsj_undotree.diffbufnr, 'modifiable', true)
  vim.cmd[[silent exe '1,$ d _']]
  local lnum = 0
  vim.api.nvim_buf_set_lines(Jsj_undotree.diffbufnr, lnum, lnum + 1, false, { old_seq .. ' --> ' .. new_seq })
  vim.api.nvim_buf_add_highlight(Jsj_undotree.diffbufnr, -1, 'UndotreeDiffLine', lnum, 0, -1)
  lnum = lnum + 1
  for _, line in ipairs(diff_lines) do
    local ch = string.sub(line, 1, 1)
    if ch == '<' or ch == '>' then
      local prefix = ch == '<' and '- ' or '+ '
      local hlgroup = ch == '<' and 'UndotreeDiffRemoved' or 'UndotreeDiffAdded'
      vim.api.nvim_buf_set_lines(Jsj_undotree.diffbufnr, lnum, lnum + 1, false, { prefix .. line:sub(3) })
      vim.api.nvim_buf_add_highlight(Jsj_undotree.diffbufnr, -1, hlgroup, lnum, 0, -1)
    elseif ch == '-' then
      lnum = lnum - 1
    else
      vim.api.nvim_buf_set_lines(Jsj_undotree.diffbufnr, lnum, lnum + 1, false, { line })
      vim.api.nvim_buf_add_highlight(Jsj_undotree.diffbufnr, -1, 'UndotreeDiffLine', lnum, 0, -1)
    end
    lnum = lnum + 1
  end
  vim.api.nvim_buf_set_option(Jsj_undotree.diffbufnr, 'modifiable', false)
end

local create_diff = function()
  local info = Jsj_undotree.asciimeta[#Jsj_undotree.charGraph - vim.fn.line('.') + 1]
  if info == nil then return end
  local cseq = info.seq
  if cseq == Jsj_undotree.seq_cur then
    local diffwinid = vim.fn.bufwinid(Jsj_undotree.diffbufnr)
    if diffwinid ~= -1 then
      vim.api.nvim_win_close(diffwinid, {force=true})
      Jsj_undotree.diffbufnr = -1
    end
    return
  end

  local old_buf_con = vim.fn.getbufline(Jsj_undotree.targetbufnr, '^', '$')
  local targetwinnr = vim.fn.bufwinnr(Jsj_undotree.targetbufnr)
  if targetwinnr == -1 then return false end
  local ev_bak = vim.opt.eventignore:get()
  vim.opt.eventignore = { "BufEnter","BufLeave","BufWinLeave","InsertLeave","CursorMoved","BufWritePost" }
  vim.cmd(string.format('silent exe "%s"', "norm! " .. targetwinnr .. "\\<c-w>\\<c-w>"))
  local savedview = vim.fn.winsaveview()
  undo2(cseq)
  local new_buf_con = vim.fn.getbufline(Jsj_undotree.targetbufnr, '^', '$')
  undo2(Jsj_undotree.seq_cur)
  vim.fn.winrestview(savedview)

  local tempfile1 = vim.fn.tempname()  -- old buf
  local tempfile2 = vim.fn.tempname()  -- new buf
  if vim.fn.writefile(old_buf_con, tempfile1) == -1 then
    vim.api.nvim_err_writeln(tempfile1 .. '(tempfile1) can not be written.')
  end
  if vim.fn.writefile(new_buf_con, tempfile2) == -1 then
    vim.api.nvim_err_writeln(tempfile2 .. '(tempfile2) can not be written.')
  end
  local diff_res = vim.fn.split(vim.fn.system('diff ' .. tempfile1 .. ' ' .. tempfile2), '\n')
  if not os.remove(tempfile1) then
    vim.api.nvim_err_writeln(tempfile1 .. '(tempfile1) can not be removed.')
  end
  if not os.remove(tempfile2) then
    vim.api.nvim_err_writeln(tempfile2 .. '(tempfile2) can not be removed.')
  end

  vim.cmd(string.format('silent exe "%s"', "norm! " .. vim.fn.bufwinnr(Jsj_undotree.diffbufnr) .. "\\<c-w>\\<c-w>"))
  parseDiffInfo(diff_res, Jsj_undotree.seq_cur, cseq)
  vim.opt.eventignore = ev_bak
end

diff.update_diff = function()
  if vim.fn.bufwinnr(Jsj_undotree.diffbufnr) == -1 then
    create_float_window()
  end
  create_diff()
  if vim.fn.bufnr() ~= Jsj_undotree.bufnr then
    local ev_bak = vim.opt.eventignore:get()
    vim.opt.eventignore = { "BufEnter","BufLeave","BufWinLeave","InsertLeave","CursorMoved","BufWritePost" }
    vim.cmd(string.format('silent exe "%s"', "norm! " .. vim.fn.bufwinnr(Jsj_undotree.bufnr) .. "\\<c-w>\\<c-w>"))
    vim.opt.eventignore = ev_bak
  end
end

return diff
