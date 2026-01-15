local kit = require("undotree.kit")
local fmt = string.format

local _M = {}

local diff_fn = vim.text and vim.text.diff or vim.diff

--- the caller must set the window
--- @param rt_ctx table runtime_ctx
--- @return table
local get_cursor_seq_content = function(rt_ctx, cur_seq, cursor_seq)
    local lines = nil

    vim.api.nvim_win_call(rt_ctx.target_winid, function()
        local saved_view = vim.fn.winsaveview()

        local ok = kit.undo2(nil, cursor_seq)
        assert(ok == true)

        lines = vim.api.nvim_buf_get_lines(rt_ctx.target_bufnr, 0, -1, false)

        ok = kit.undo2(nil, cur_seq)
        assert(ok == true)

        vim.fn.winrestview(saved_view)
    end)

    assert(lines ~= nil)
    return lines
end

--- @param rt_ctx table runtime_ctx
--- @return table? lines
--- @return table? hls
_M.get_diff_content = function(rt_ctx, cur_seq, cursor_seq)
    local d_ctx = rt_ctx.diff_ctx
    if d_ctx.last_cur_seq == cur_seq and d_ctx.last_cursor_seq == cursor_seq then
        return nil, nil
    end

    d_ctx.last_cur_seq = cur_seq
    d_ctx.last_cursor_seq = cursor_seq

    local lines = { fmt("%s --> %s", cur_seq, cursor_seq) }
    local hls = { "UndotreeDiffLine" }

    if cur_seq == cursor_seq then
        return lines, hls
    end

    local cur_content = vim.api.nvim_buf_get_lines(rt_ctx.target_bufnr, 0, -1, false)
    local cursor_content = get_cursor_seq_content(rt_ctx, cur_seq, cursor_seq)

    local cb = function(start_old, count_old, start_new, count_new)
        table.insert(
            lines,
            -- unified diff hunk header
            fmt("@@ -%d,%d +%d,%d @@", start_old, count_old, start_new, count_new)
        )
        table.insert(hls, "UndotreeDiffLine")

        if count_old ~= 0 then
            for i = 0, count_old - 1 do
                table.insert(lines, "- " .. cur_content[start_old + i])
                table.insert(hls, "UndotreeDiffRemoved")
            end
        end
        if count_new ~= 0 then
            for i = 0, count_new - 1 do
                table.insert(lines, "+ " .. cursor_content[start_new + i])
                table.insert(hls, "UndotreeDiffAdded")
            end
        end
    end

    diff_fn(table.concat(cur_content, "\n"), table.concat(cursor_content, "\n"), {
        result_type = "indices",
        on_hunk = cb,
        algorithm = "histogram",
    })

    return lines, hls
end

return _M
