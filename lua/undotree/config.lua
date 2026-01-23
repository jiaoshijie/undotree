local _M = {}

_M.common = {
    -- NOTE: some special buffer's filetypes don't need to put here.
    -- Because these buffer's buftype is likely not empty, e.g. quickfix, help.
    ignore_filetype = {},
    --- @type "compact" | "legacy"
    parser = "compact",
}

_M.ui_cfg = {
    float_diff = true,       -- set this `true` will disable layout option
    --- @type "left_bottom" | "left_left_bottom"
    layout = "left_bottom",   -- {left}_{bottom} {left}_{left_bottom}
    --- @type "left" | "right"
    position = "left",
    window = {
        width = 0.25,  -- the `undotree` window width percentage related to the editor
        height = 0.25, -- the `preview`(not floating) window height percentage related to the editor
        border = "rounded",  -- float window
    },
}

_M.keymaps_cfg = {
    ['j'] = "move_next",
    ['k'] = "move_prev",
    ['gj'] = "move2parent",
    ['J'] = "move_change_next",
    ['K'] = "move_change_prev",
    ['<cr>'] = "action_enter",
    ['p'] = "enter_diffbuf",    -- this can switch between preview and undotree window
    ['q'] = "quit",
    ['S'] = "update_undotree_view",
}

-- NOTE: this code is ugly, but it's for backward compatibility
_M.setup = function(cfg)
    _M.common = vim.tbl_extend("force", _M.common, {
        ignore_filetype = cfg.ignore_filetype,
        parser = cfg.parser,
    })
    cfg.ignore_filetype = nil
    cfg.parser = nil

    _M.keymaps_cfg = vim.tbl_extend("force", _M.keymaps_cfg, cfg.keymaps)
    cfg.keymaps = nil

    _M.ui_cfg = vim.tbl_deep_extend("force", _M.ui_cfg, cfg)
end

return _M
