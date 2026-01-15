local _M = {}

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move_next = function(rt_ctx, rt_ops)
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move_prev = function(rt_ctx, rt_ops)
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move2parent = function(rt_ctx, rt_ops)
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move_change_next = function(rt_ctx, rt_ops)
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move_change_prev = function(rt_ctx, rt_ops)
end

--- apply the node under the cursor
--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.action_enter = function(rt_ctx, rt_ops)
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.quit = function(rt_ctx, rt_ops)
    local _ = rt_ctx
    rt_ops.close()
end

--- move cursor between undotree and preview windows
--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.enter_diffbuf = function(rt_ctx, rt_ops)
    local _ = rt_ops
    local winid = vim.api.nvim_get_current_win()

    if winid == rt_ctx.p_winid then
        vim.fn.win_gotoid(rt_ctx.winid)
        return
    end

    if rt_ctx.p_winid and vim.api.nvim_win_is_valid(rt_ctx.p_winid) then
        vim.fn.win_gotoid(rt_ctx.p_winid)
    end
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.update_undotree_view = function(rt_ctx, rt_ops)
end

return _M
