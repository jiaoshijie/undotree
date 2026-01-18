local highlights = {
    UndotreeFirstNode = { default = true, link = "Conceal" },
    UndotreeNode = { default = true, link = "Question" },
    UndotreeSeq = { default = true, link = "Question" },
    UndotreeCurrent = { default = true, link = "Statement" },
    UndotreeTimeStamp = { default = true, link = "Conceal" },
    UndotreeSaved = { default = true, link = "Label" },
    UndotreeBranch = { default = true, link = "Constant" },

    UndotreeDiffLine = { default = true, link = "diffLine" },
    UndotreeDiffAdded = { default = true, link = "diffAdded" },
    UndotreeDiffRemoved = { default = true, link = "diffRemoved" },
}

for k, v in pairs(highlights) do
    vim.api.nvim_set_hl(0, k, v)
end

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
