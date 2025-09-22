local highlights = {
  UndotreeFirstNode = { default = true, link = "Function" },
  UndotreeNode = { default = true, link = "Question" },
  UndotreeSeq = { default = true, link = "Comment" },
  UndotreeCurrent = { default = true, link = "Statement" },
  UndotreeTimeStamp = { default = true, link = "Function" },
  UndotreeSaved = { default = true, link = "Conceal" },
  UndotreeBranch = { default = true, link = "Constant" },
  UndotreeDiffLine = { default = true, link = "diffLine" },
  UndotreeDiffAdded = { default = true, link = "diffAdded" },
  UndotreeDiffRemoved = { default = true, link = "diffRemoved" },
}

for k, v in pairs(highlights) do
  vim.api.nvim_set_hl(0, k, v)
end

require("undotree").setup()

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
