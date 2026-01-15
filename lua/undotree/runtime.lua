local cfg = require("undotree.config")
local kit = require("undotree.kit")
local ui = require("undotree.ui")
local action = require("undotree.action")
local fmt = string.format

local _M = {}

local ctx = {
    winid = nil,
    bufnr = nil,
    p_winid = nil,
    p_bufnr = nil,

    target_winid = nil,
    target_bufnr = nil,
    win_fix_buf = nil,

    cur_seq = nil,
    max_seq = nil,
    line2seq = nil,
    seq2line = nil,
    parser_ctx = {
    },

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
        kit.echo_err_msg("This buffer is not associated with a disk file")
        return false
    end

    -- 3. if this buffer is `nomodifiable`
    if vim.bo.modifiable ~= true then
        kit.echo_err_msg("This buffer is nomodifiable")
        return false
    end

    -- 4. if this file is read-only
    if vim.bo.readonly == true then
        kit.echo_err_msg("This buffer is readonly")
        return false
    end

    -- 5. user ignored filetype
    if vim.tbl_contains(cfg.common.ignore_filetype, vim.bo.filetype) then
        kit.echo_err_msg(fmt("filetype `%s` is ignored", vim.bo.filetype))
        return false
    end

    return true
end

local set_target = function()
    ctx.target_bufnr = vim.api.nvim_get_current_buf()
    ctx.target_winid = vim.api.nvim_get_current_win()
    ctx.win_fix_buf = vim.api.nvim_get_option_value("winfixbuf", { win = ctx.target_winid })
    vim.api.nvim_set_option_value("winfixbuf", true, { win = ctx.target_winid })
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
        callback = function() _M.close() end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = ctx.target_bufnr,
        group = group,
        callback = function(ev)
            if tonumber(ev.match) == ctx.target_winid then
                _M.close()
            end
        end,
    })
end

local set_keymaps = function()
    local map_opts = { noremap = true, silent = true, buffer = ctx.bufnr }

    for k, v in pairs(cfg.keymaps_cfg) do
        vim.keymap.set("n", k, function() action[v](ctx, _M) end, map_opts)
    end
    map_opts.buffer = ctx.p_bufnr
    vim.keymap.set("n", "p", function() action["enter_diffbuf"](ctx, _M) end, map_opts)
    vim.keymap.set("n", "q", function() _M.close() end, map_opts)
end

local set_buf_options = function()
    vim.api.nvim_set_option_value("filetype", "Undotree", { buf = ctx.bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = ctx.bufnr })

    vim.api.nvim_set_option_value("filetype", "UndotreeDiff", { buf = ctx.p_bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = ctx.p_bufnr })
end

local prepare_buffers = function()
    assert(ctx.bufnr == nil)

    ctx.bufnr = vim.api.nvim_create_buf(false, true)
    ctx.p_bufnr = vim.api.nvim_create_buf(false, true)
    set_buf_options()
    set_keymaps()
    set_events()
end

--- @return boolean
_M.is_opened = function()
    return ctx.bufnr ~= nil
end

_M.open = function()
    if not validate_env() then return end
    set_target()
    -- 1. parse the internal undotree
    -- 2. get diff content by default it should always be empty

    -- 3. perpare the buffers
    prepare_buffers()
    -- 4. render the window
    ui.render(ctx)
    ui.render_diff(ctx)
end

_M.close = function()
    if not _M.is_opened() then return end

    if vim.api.nvim_win_is_valid(ctx.target_winid) then
        vim.api.nvim_set_option_value("winfixbuf", ctx.win_fix_buf, { win = ctx.target_winid })
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

    -- TODO: cseq
    -- TODO: clear parser_ctx

    ctx.preview_layout = nil
end

--- @return boolean
_M.is_visible_on_cur_tab = function()
    if not _M.is_opened() then return false end
    return kit.winid_in_tab(ctx.winid)
end

return _M
