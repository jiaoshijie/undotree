local cfg = require("undotree.config")
local kit = require("undotree.kit")
local ui = require("undotree.ui")
local action = require("undotree.action")
local parser = require("undotree.parser")
local diff = require("undotree.diff")
local fmt = string.format

local _M = {}

--- @type integer
local diff_ns = nil

local ctx = {
    winid = nil,
    bufnr = nil,
    p_winid = nil,
    p_bufnr = nil,

    target_winid = nil,
    target_bufnr = nil,
    win_fix_buf = nil,

    prev_seq = nil,
    cur_seq = nil,
    max_seq = nil,
    line2seq = nil, --- @type Line2Seq
    seq2line = nil, --- @type Seq2Line

    diff_ctx = {
        last_cur_seq = nil,
        last_cursor_seq = nil,
    },

    preview_layout = nil,
}

--- @return boolean
local validate_env = function()
    -- 1. check whether it is already opened
    if _M.is_opened() then
        kit.echo_err_msg("Undotree has already opened")
        return false
    end

    -- 2. if buftype is not empty do not open undotree
    -- This also prevents user open the undotree from command line window
    if #vim.bo.buftype > 0 then
        kit.echo_err_msg("buftype is not empty `:h 'buftype'`")
        return false
    end

    -- 3. if this buffer is `nomodifiable`
    if vim.bo.modifiable ~= true then
        kit.echo_err_msg("buffer is nomodifiable")
        return false
    end

    -- 4. if this file is read-only
    if vim.bo.readonly == true then
        kit.echo_err_msg("buffer is readonly")
        return false
    end

    -- 5. user ignored filetype
    if vim.tbl_contains(cfg.common.ignore_filetype, vim.bo.filetype) then
        kit.echo_err_msg(fmt("filetype `%s` is ignored", vim.bo.filetype))
        return false
    end

    if not diff_ns then
        diff_ns = vim.api.nvim_create_namespace("undotree_diff_preview_ns")
    end

    return true
end

local set_target = function()
    ctx.target_bufnr = vim.api.nvim_get_current_buf()
    ctx.target_winid = vim.api.nvim_get_current_win()
    ctx.win_fix_buf = vim.api.nvim_get_option_value("winfixbuf", { win = ctx.target_winid })
    vim.api.nvim_set_option_value("winfixbuf", true, { win = ctx.target_winid })
end

-- NOTE: this function should rarely be called
local gracefully_quit = function()
    local win_num = cfg.ui_cfg.float_diff and 2 or 3

    if kit.get_cur_tab_layout_wins() <= win_num then
        local cmd = #vim.api.nvim_list_tabpages() > 1 and "tabclose" or "qall"
        local save_ei = vim.o.eventignore
        vim.o.eventignore = "all"
        vim.cmd(cmd)
        vim.o.eventignore = save_ei
    end
    _M.close()
end

local set_events = function()
    local group = vim.api.nvim_create_augroup("undotree_rt_event", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = ctx.bufnr,
        group = group,
        callback = function(ev)
            -- Both <amatch> and <afile> are set to the |window-ID|
            if tonumber(ev.match) == ctx.winid then
                _M.close()
            end
        end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = ctx.p_bufnr,
        group = group,
        callback = function()
            _M.close()
        end,
    })

    -- NOTE: this event should rarely be triggered
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = ctx.target_bufnr,
        group = group,
        callback = function(ev)
            if tonumber(ev.match) == ctx.target_winid then
                gracefully_quit()
            end
        end,
    })
end

local set_keymaps = function()
    local map_opts = { noremap = true, silent = true, buffer = ctx.bufnr }

    for k, v in pairs(cfg.keymaps_cfg) do
        vim.keymap.set("n", v, function()
            action[k](ctx, _M)
        end, map_opts)
    end
    map_opts.buffer = ctx.p_bufnr
    vim.keymap.set("n", cfg.keymaps_cfg["enter_diffbuf"], function()
        action["enter_diffbuf"](ctx, _M)
    end, map_opts)
    vim.keymap.set("n", cfg.keymaps_cfg["quit"], function()
        _M.close()
    end, map_opts)
end

local set_user_cmd = function()
    vim.api.nvim_buf_create_user_command(ctx.bufnr, "UndotreeClearHistory", function()
        -- NOTE: this only clear the in-memory undo histroy.
        -- To make the undo history clearing permanent, write the buffer to disk manually.
        -- To discard this clearing, delete the buf from buflist or quit vim without saving this buffer.
        local ok, ret =
            pcall(vim.fn.confirm, "Clear the whole undo history?", "&Yes\n&No", 2, "Warning")

        if ok and ret == 1 then
            kit.clear_whole_undo_history(ctx.target_bufnr)
            _M.update_graph(true)
        end
    end, { nargs = 0 })

    vim.api.nvim_buf_create_user_command(ctx.bufnr, "UndotreeRename", function()
        kit.rename(ctx.target_bufnr)
    end, { nargs = 0 })
end

local set_buf_options = function()
    vim.api.nvim_set_option_value("filetype", "undotree", { buf = ctx.bufnr })
    vim.api.nvim_set_option_value("undolevels", -1, { buf = ctx.bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = ctx.bufnr })

    vim.api.nvim_set_option_value("filetype", "UndotreeDiff", { buf = ctx.p_bufnr })
    vim.api.nvim_set_option_value("undolevels", -1, { buf = ctx.p_bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = ctx.p_bufnr })
end

local prepare_buffers = function()
    assert(ctx.bufnr == nil)

    ctx.bufnr = vim.api.nvim_create_buf(false, true)
    ctx.p_bufnr = vim.api.nvim_create_buf(false, true)
    set_buf_options()
    set_keymaps()
    set_events()
    set_user_cmd()
end

local update_mark = function(lnum)
    -- >num< : The current state
    local prev_line, cur_line, prev_lnum

    if ctx.prev_seq then
        prev_lnum = ctx.seq2line[ctx.prev_seq]
        prev_line = vim.fn.substitute(vim.fn.getline(prev_lnum), [[\zs>\(\d\+\)<\ze]], [[\1]], "")
    end
    cur_line = vim.fn.substitute(vim.fn.getline(lnum), [[\zs\(\d\+\)\ze]], [[>\1<]], "")

    kit.modify_buf(ctx.bufnr, function()
        if prev_line then
            vim.fn.setline(prev_lnum, prev_line)
        end
        vim.fn.setline(lnum, cur_line)
    end)
end

local update_diff = function(lnum)
    local cursor_seq = ctx.line2seq[lnum].seq_node.seq

    local lines, hls = diff.get_diff_content(ctx, ctx.cur_seq, cursor_seq)
    if lines == nil or hls == nil then
        return
    end

    if cfg.ui_cfg.float_diff and cursor_seq == ctx.cur_seq then
        if ctx.p_winid and vim.api.nvim_win_is_valid(ctx.p_winid) then
            kit.win_delete(ctx.p_winid, true)
            ctx.p_winid = nil
        end
        return
    end

    kit.modify_buf(ctx.p_bufnr, function()
        vim.api.nvim_buf_set_lines(ctx.p_bufnr, 0, -1, false, lines)
        for i, hl in ipairs(hls) do
            vim.hl.range(ctx.p_bufnr, diff_ns, hl, { i - 1, 0 }, { i - 1, -1 })
        end
    end)

    if not ctx.p_winid then
        ui.render_diff(ctx)
    end
end

_M.apply = function(lnum)
    local seqline = ctx.line2seq[lnum]
    if not seqline or not seqline.seq_node or ctx.cur_seq == seqline.seq_node.seq then
        return
    end
    ctx.prev_seq = ctx.cur_seq
    ctx.cur_seq = seqline.seq_node.seq
    update_mark(lnum)
    kit.undo2(ctx.target_winid, ctx.cur_seq)
    update_diff(lnum)
end

--- @param lnum integer
--- @param direction integer
--- @param apply boolean?
_M.set_cursor = function(lnum, direction, apply)
    -- NOTE: does not need to check boundaries
    while ctx.line2seq[lnum].seq_node == nil do
        lnum = lnum + direction
    end

    local col = string.find(vim.fn.getline(lnum), "*")
    vim.api.nvim_win_set_cursor(ctx.winid, { lnum, col and col - 1 or 0 })

    if apply then
        _M.apply(lnum)
    else
        update_diff(lnum)
    end
end

--- @param direction integer
--- @param apply boolean?
_M.move_selection = function(direction, apply)
    local pos = vim.api.nvim_win_get_cursor(ctx.winid)
    local lnum = pos[1] + direction
    if lnum <= 0 or lnum > #ctx.line2seq then
        return
    end

    _M.set_cursor(lnum, direction, apply)
end

--- @param nullable boolean
_M.update_graph = function(nullable)
    local graph = parser.parse_undotree(ctx)
    if nullable and graph == nil then
        return
    end

    assert(graph ~= nil)
    kit.modify_buf(ctx.bufnr, function()
        vim.api.nvim_buf_set_lines(ctx.bufnr, 0, -1, false, graph)
    end)

    local lnum = ctx.seq2line[ctx.cur_seq]
    -- 0 is OK
    _M.set_cursor(lnum, 0)
    update_mark(lnum)
end

--- @return boolean
_M.is_opened = function()
    return ctx.bufnr ~= nil
end

_M.open = function()
    if not validate_env() then
        return
    end
    set_target()

    prepare_buffers()
    ui.render(ctx)

    _M.update_graph(false)
end

_M.close = function()
    if not _M.is_opened() then
        return
    end

    if vim.api.nvim_win_is_valid(ctx.target_winid) then
        vim.api.nvim_set_option_value("winfixbuf", ctx.win_fix_buf, { win = ctx.target_winid })
        vim.api.nvim_set_current_win(ctx.target_winid)
    end
    ctx.target_bufnr = nil
    ctx.target_winid = nil

    kit.win_delete(ctx.winid, true)
    kit.buf_delete(ctx.bufnr)
    ctx.winid = nil
    ctx.bufnr = nil
    kit.win_delete(ctx.p_winid, true)
    kit.buf_delete(ctx.p_bufnr)
    ctx.p_winid = nil
    ctx.p_bufnr = nil
    vim.api.nvim_clear_autocmds({ group = "undotree_rt_event" })

    ctx.prev_seq = nil
    ctx.cur_seq = nil
    ctx.max_seq = nil
    ctx.line2seq = nil
    ctx.seq2line = nil

    ctx.diff_ctx.last_cur_seq = nil
    ctx.diff_ctx.last_cursor_seq = nil

    ctx.preview_layout = nil
end

--- @return boolean
_M.is_visible_on_cur_tab = function()
    if not _M.is_opened() then
        return false
    end
    return kit.winid_in_tab(ctx.winid)
end

return _M
