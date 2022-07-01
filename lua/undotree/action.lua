local action = {}

local enter = function(collector)
  local cseq = collector.undotree_info.asciimeta[#collector.undotree_info.charGraph - vim.fn.line('.') + 1].seq
  collector:undo2(cseq)
  collector:reflashDiff()
end

function action.move_next(collector)
  collector:move_selection(1)
end

function action.move_prev(collector)
  collector:move_selection(-1)
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
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. collector.diff_win .. ")")
end

function action.quit(collector)
  collector:close()
end

return action
