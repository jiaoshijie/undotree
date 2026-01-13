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

    if cfg.float_diff == false then
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

return _M
