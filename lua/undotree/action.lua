local _M = {}

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move_next = function(rt_ctx, rt_ops)
    local _ = rt_ctx
    rt_ops.move_selection(1)
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move_prev = function(rt_ctx, rt_ops)
    local _ = rt_ctx
    rt_ops.move_selection(-1)
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move2parent = function(rt_ctx, rt_ops)
    local pos = vim.api.nvim_win_get_cursor(rt_ctx.winid)
    local seqline = rt_ctx.line2seq[pos[1]]
    if not seqline or not seqline.seq_node then
        return
    end
    local seq = seqline.seq_node.parent_seq
    local lnum = rt_ctx.seq2line[seq]
    -- root (or missing) parent should not move the cursor.
    if not lnum then
        return
    end
    rt_ops.set_cursor(lnum, 0)
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move_change_next = function(rt_ctx, rt_ops)
    local _ = rt_ctx
    rt_ops.move_selection(1, true)
end

--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.move_change_prev = function(rt_ctx, rt_ops)
    local _ = rt_ctx
    rt_ops.move_selection(-1, true)
end

--- apply the node under the cursor
--- @param rt_ctx table runtime_ctx
--- @param rt_ops table runtime_operations
_M.action_enter = function(rt_ctx, rt_ops)
    local pos = vim.api.nvim_win_get_cursor(rt_ctx.winid)
    rt_ops.apply(pos[1])
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
    local _ = rt_ctx
    rt_ops.update_graph(true)
end

return _M
