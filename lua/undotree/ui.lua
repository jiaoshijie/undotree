local cfg = require("undotree.config").ui_cfg

local _M = {}

local gen_win_layout = function()
    local round = math.ceil
    local max_col, max_line = vim.o.columns, vim.o.lines

    max_line = max_line - vim.o.cmdheight
    if vim.o.ls ~= 0 then max_line = max_line - 1 end
    if #vim.o.winbar ~= 0 then max_line = max_line - 1 end

    local main = {
        -- default is left
        win = -1,
        split = cfg.position == "right" and "right" or "left",
        width = round(max_col * cfg.window.width),
        style = "minimal",
        noautocmd = true,
    }

    if not cfg.float_diff then
        local preview = {
            -- nil using the main winid
            -- default is left_bottom
            win = cfg.layout ~= "left_left_bottom" and -1 or nil,
            split = "below",
            height = round(max_line * cfg.window.height),
            style = "minimal",
            noautocmd = true,
        }
        return main, preview
    end

    local width = round((max_col - main.width) * 0.8)
    local height = round(max_line * 0.8)

    local col
    if main.split == "left" then
        col = round((max_col + main.width - width) / 2)
    else
        col = round((max_col - main.width - width) / 2)
    end

    -- floating things
    local preview = {
        relative = "editor",
        row = round((max_line - height) / 2),
        col = col,
        width = width,
        height = height,
        style = "minimal",
        noautocmd = true,
        border = cfg.window.border or "rounded",
        title = " diff preview ",
        title_pos = "center",
    }

    return main, preview
end

--- @param winid number
--- @param undo_win boolean
local set_win_opts = function(winid, undo_win)
    vim.api.nvim_set_option_value('cursorline', undo_win, { win = winid })

    vim.api.nvim_set_option_value('winblend', 0, { win = winid })
    vim.api.nvim_set_option_value('winbar', "", { win = winid })
    vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
    vim.api.nvim_set_option_value('scrolloff', 0, { win = winid })
    vim.api.nvim_set_option_value('wrap', false, { win = winid })
    vim.api.nvim_set_option_value('foldenable', false, { win = winid })
    vim.api.nvim_set_option_value('colorcolumn', '0', { win = winid })
    vim.api.nvim_set_option_value('winfixbuf', true, { win = winid })
    vim.api.nvim_set_option_value('winfixwidth', true, { win = winid })
end


--- @param rt_ctx table runtime_ctx
_M.render = function(rt_ctx)
    local main, preview = gen_win_layout()
    rt_ctx.winid = vim.api.nvim_open_win(rt_ctx.bufnr, true, main)
    set_win_opts(rt_ctx.winid, true)

    if not cfg.float_diff and preview.win == nil then
        preview.win = rt_ctx.winid
    end

    rt_ctx.preview_layout = preview
end

_M.render_diff = function(rt_ctx)
    if rt_ctx.p_winid and vim.api.nvim_win_is_valid(rt_ctx.p_winid) then
        return
    end

    rt_ctx.p_winid = vim.api.nvim_open_win(rt_ctx.p_bufnr, false, rt_ctx.preview_layout)
    set_win_opts(rt_ctx.p_winid, false)
end

return _M
