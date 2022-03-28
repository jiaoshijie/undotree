local undotree = require('undotree.undotree')
local actions = require('undotree.actions')
local _M = {}
local jsj_undotree = undotree:new()
local mappings = {
  k = 'prev_star',
  j = 'next_star',
  Q = 'quit_undotree',
  q = 'quit_diff_win',
  K = 'prev_state',
  J = 'next_state',
  p = 'showOrFocusDiffWindow',
  ['<cr>'] = 'actionEnter',
}
local keymap_store = {}

local _mapping_key_id = 0
local get_next_id = function()
  _mapping_key_id = _mapping_key_id + 1
  return _mapping_key_id
end

local assign_function = function(func)
  local func_id = get_next_id()
  keymap_store[func_id] = func
  return func_id
end

local undotree_map = function(mode, key_bind, key_func, opts)
  local func_id = assign_function(key_func)
  local map_string = string.format(
  ":lua require('undotree').execute_keymap(%s)<cr>",
  func_id
  )
  vim.api.nvim_buf_set_keymap(jsj_undotree.bufnr, mode, key_bind, map_string, opts)
end


local function update()
  if vim.bo.filetype == 'undotree' or vim.bo.filetype == 'qf' then
    return
  end
  local newtree = vim.fn.undotree()
  if jsj_undotree.seq_last ~= newtree.seq_last then
    jsj_undotree:clear()
    jsj_undotree.seq_last = newtree.seq_last
    jsj_undotree.targetbufnr = vim.fn.bufnr()  -- set really undo buf
    local tree = {seq=0}
    jsj_undotree:parseEntries(newtree.entries, tree)
    jsj_undotree:getGraphInfo(tree)
    jsj_undotree:update_undotree()
    for key, func in pairs(mappings) do
      undotree_map('n', key, actions[func], {noremap=true, silent=true})
    end
  end
  jsj_undotree.seq_cur = newtree.seq_cur
  actions.setFocus(jsj_undotree)
  local lnum = jsj_undotree.asciimeta[jsj_undotree.seq2index[jsj_undotree.seq_cur]].lnum
  vim.fn.cursor({lnum, actions.findStar(lnum)})
  jsj_undotree:setMark()
end

_M.toggle = function()
  if jsj_undotree ~= nil and vim.fn.bufwinnr(jsj_undotree.bufnr) ~= -1 then
    actions.quit_undotree(jsj_undotree)
  else
    update()
  end
end

_M.execute_keymap = function(keymap_identifier)
  local key_func = keymap_store[keymap_identifier]
  key_func(jsj_undotree)
end

return _M
