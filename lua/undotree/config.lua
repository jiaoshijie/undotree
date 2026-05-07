local _M = {}

_M.common = {
    -- NOTE: some special buffer's filetypes don't need to put here.
    -- Because these buffer's buftype is likely not empty, e.g. quickfix, help.
    ignore_filetype = {},
    --- @type "compact" | "legacy"
    parser = "compact",
}

_M.ui_cfg = {
    float_diff = true, -- set this `true` will disable layout option
    --- @type "left_bottom" | "left_left_bottom"
    layout = "left_bottom", -- {left}_{bottom} {left}_{left_bottom}
    --- @type "left" | "right"
    position = "left",
    window = {
        width = 0.25, -- the `undotree` window width percentage related to the editor
        height = 0.25, -- the `preview`(not floating) window height percentage related to the editor
        border = "rounded", -- float window
    },
}

_M.keymaps_cfg = {
    ["move_next"] = "j",
    ["move_prev"] = "k",
    ["move2parent"] = "gj",
    ["move_change_next"] = "J",
    ["move_change_prev"] = "K",
    ["action_enter"] = "<cr>",
    ["enter_diffbuf"] = "p", -- is defined for both undotree and preview buffers, so it works as a toggle
    ["quit"] = "q", -- is defined for both undotree and preview buffers
    ["update_undotree_view"] = "S",
}

-- NOTE: this code is ugly, but it's for backward compatibility
_M.setup = function(cfg)
    if type(cfg) ~= "table" then
        return
    end

    _M.common = vim.tbl_extend("force", _M.common, {
        ignore_filetype = cfg.ignore_filetype,
        parser = cfg.parser,
    })
    cfg.ignore_filetype = nil
    cfg.parser = nil

    if type(cfg.keymaps) == "table" then
        -- backward compatibility for old keymaps table
        local next_key, _ = next(cfg.keymaps)
        if _M.keymaps_cfg[next_key] == nil then
            vim.defer_fn(function()
                vim.notify(
                    "WARNING: `keymaps = { [lhs] = action }` is deprecated; "
                        .. "use `keymaps = { [action] = lhs }` instead.\n"
                        .. "See `:h undotree-configuration` for details.",
                    vim.log.levels.WARN,
                    { title = "Undotree Config", timeout = 5000 }
                )
            end, 500)
            -- NOTE: the only issue of flipping will be if the user
            -- for some reason uses multiple keymaps for the same action
            local flipped_keymaps = {}
            for k, v in pairs(cfg.keymaps) do
                flipped_keymaps[v] = k
            end
            cfg.keymaps = flipped_keymaps
        end

        _M.keymaps_cfg = vim.tbl_extend("force", _M.keymaps_cfg, cfg.keymaps)
    end
    cfg.keymaps = nil

    _M.ui_cfg = vim.tbl_deep_extend("force", _M.ui_cfg, cfg)
end

return _M
