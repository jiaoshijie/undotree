vim.cmd.syntax([[match UndotreeFirstNode 'Original']])
vim.cmd.syntax([[match UndotreeNode '\zs\*\ze']])
vim.cmd.syntax([[match UndotreeSeq ' \zs\d\+\ze ']])
vim.cmd.syntax([[match UndotreeCurrent '>\d\+<']])
vim.cmd.syntax([[match UndotreeTimeStamp '(.*)$']])
vim.cmd.syntax([[match UndotreeSaved ' \zss\ze ']])
vim.cmd.syntax([[match UndotreeBranch '[|-]']])

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
