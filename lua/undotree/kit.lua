local _M = {}
local fmt = string.format

--- @param msg string
_M.echo_err_msg = function(msg)
    vim.api.nvim_echo({ { fmt("undotree: %s", msg) } }, true, { err = true })
end

_M.echo_info_msg = function(msg)
    vim.api.nvim_echo({ { fmt("undotree: %s", msg) } }, true, { err = false })
end

--- @param bufnr integer
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

--- @param win_id integer
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

--- @param winid integer?
--- @return boolean
_M.winid_in_tab = function(winid)
    if winid == nil then return false end
    return vim.fn.tabpagenr() == vim.fn.win_id2tabwin(winid)[1]
end

--- @param t integer time in sec
--- @return string
_M.time_ago = function(t)
    local round = math.ceil
    local tick = vim.fn.localtime() - t
    local fmt_time = function(unit)
        return fmt("%s %s%s ago", tick, unit, tick > 1 and "s" or "")
    end

    if tick < 60 then return fmt_time("sec") end

    tick = round(tick / 60)
    if tick < 60 then return fmt_time("min") end

    tick = round(tick / 60)
    if tick < 24 then return fmt_time("hour") end

    tick = round(tick / 24)
    return fmt_time("day")
end

--- @param bufnr integer
--- @param cb fun()
_M.modify_buf = function(bufnr, cb)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
        return
    end

    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    cb()
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

--- @param seq integer
--- @return boolean  true: success, false: failed
_M.undo2 = function(winid, seq)
    local ok = false
    local cb = function()
        --- @diagnostic disable
        --- TODO: maybe need more modifiers for the undo command
        ok, _ = pcall(vim.cmd, fmt("silent! undo%d", seq))
    end

    if winid then
        assert(vim.api.nvim_win_is_valid(winid) == true)
        vim.api.nvim_win_call(winid, cb)
    else
        cb()
    end

    return ok
end

--- get the number of windows except floating window
--- @return integer
_M.get_cur_tab_layout_wins = function()
    local all_wins = vim.api.nvim_tabpage_list_wins(0)
    local num = 0
    for _, id in next, all_wins do
        if vim.api.nvim_win_get_config(id).relative == "" then
            num = num + 1
        end
    end
    return num
end

return _M
