---@module 'undotree.collector'

---@class UndoTreeAction
local action = {}

---@param collector? UndoTreeCollector
function action.enter(collector)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("collector", collector, "table", true, "UndoTreeCollector")
  else
    vim.validate({ collector = { collector, { "table", "nil" } } })
  end

  if not collector then
    return
  end

  local cseq = collector.undotree_info.line2seq[vim.fn.line(".")]
  collector:undo2(cseq)
  collector:reflash_diff()
end

---@param collector UndoTreeCollector
function action.move_next(collector)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("collector", collector, "table", false, "UndoTreeCollector")
  else
    vim.validate({ collector = { collector, "table" } })
  end
  collector:move_selection(1)
end

---@param collector UndoTreeCollector
function action.move_prev(collector)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("collector", collector, "table", false, "UndoTreeCollector")
  else
    vim.validate({ collector = { collector, "table" } })
  end
  collector:move_selection(-1)
end

---@param collector UndoTreeCollector
function action.move2parent(collector)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("collector", collector, "table", false, "UndoTreeCollector")
  else
    vim.validate({ collector = { collector, "table" } })
  end
  local cu = collector.undotree_info
  local parent_seq = cu.seq2parent[cu.line2seq[vim.fn.line(".")]]
  local lnum = cu.seq2line[parent_seq]
  collector:move_selection(lnum - vim.fn.line("."))
end

---@param collector UndoTreeCollector
function action.move_change_next(collector)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("collector", collector, "table", false, "UndoTreeCollector")
  else
    vim.validate({ collector = { collector, "table" } })
  end
  collector:move_selection(1, true)
  action.enter(collector)
end

---@param collector UndoTreeCollector
function action.move_change_prev(collector)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("collector", collector, "table", false, "UndoTreeCollector")
  else
    vim.validate({ collector = { collector, "table" } })
  end
  collector:move_selection(-1, true)
  action.enter(collector)
end

---@param collector UndoTreeCollector
function action.action_enter(collector)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("collector", collector, "table", false, "UndoTreeCollector")
  else
    vim.validate({ collector = { collector, "table" } })
  end
  action.enter(collector)
end

---@param collector UndoTreeCollector
function action.enter_diffbuf(collector)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("collector", collector, "table", false, "UndoTreeCollector")
  else
    vim.validate({ collector = { collector, "table" } })
  end
  if not collector.diff_win then
    error("There is no diff window found!!!", vim.log.levels.ERROR)
  end

  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. collector.diff_win .. ")")
end

---@param collector UndoTreeCollector
function action.quit(collector)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("collector", collector, "table", false, "UndoTreeCollector")
  else
    vim.validate({ collector = { collector, "table" } })
  end
  collector:close()
end

return action

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
