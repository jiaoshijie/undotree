local _M = {}
local fmt = string.format

--- @param msg string
_M.echo_err_msg = function(msg)
    vim.api.nvim_echo({ { fmt("undotree: %s", msg) } }, true, { err = true })
end

_M.echo_info_msg = function(msg)
    vim.api.nvim_echo({ { fmt("undotree: %s", msg) } }, true, { err = false })
end

--- @param bufnr number
_M.buf_delete = function(bufnr)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    -- Suppress the buffer deleted message for those with &report<2
    local start_report = vim.o.report
    vim.o.report = 2

    vim.api.nvim_buf_delete(bufnr, { force = true })

    vim.o.report = start_report
end

--- @param win_id number
--- @param force boolean see :h nvim_win_close
_M.win_delete = function(win_id, force)
    if not win_id or not vim.api.nvim_win_is_valid(win_id) then
        return
    end

    local save_ei = vim.o.eventignore
    vim.o.eventignore = "all"
    vim.api.nvim_win_close(win_id, force)
    vim.o.eventignore = save_ei
end

---@param T table
---@return table T
_M.reverse_table = function(T)
  if vim.tbl_isempty(T) then
    return T
  end

  local len = #T
  for i = 1, math.floor(len / 2), 1 do
    T[i], T[len - i + 1] = T[len - i + 1], T[i]
  end

  return T
end

return _M
