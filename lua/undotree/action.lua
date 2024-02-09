local action = {}

local enter = function(collector)
  local cseq = collector.undotree_info.line2seq[vim.fn.line('.')]
  collector:undo2(cseq)
  collector:reflash_diff()
end

function action.move_next(collector)
  collector:move_selection(1)
end

function action.move_prev(collector)
  collector:move_selection(-1)
end

function action.move2parent(collector)
  local cu = collector.undotree_info
  local parent_seq = cu.seq2parent[cu.line2seq[vim.fn.line('.')]]
  local lnum = cu.seq2line[parent_seq]
  collector:move_selection(lnum - vim.fn.line('.'))
end

function action.move_change_next(collector)
  collector:move_selection(1, true)
  enter(collector)
end

function action.move_change_prev(collector)
  collector:move_selection(-1, true)
  enter(collector)
end

function action.action_enter(collector)
  enter(collector)
end

function action.enter_diffbuf(collector)
  if collector.diff_win then
    vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. collector.diff_win .. ")")
  else
    vim.api.nvim_err_writeln("There is no diff window found!!!")
  end
end

function action.quit(collector)
  collector:close()
end

return action
