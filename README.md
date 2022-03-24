# Undotree

A neovim undotree plugin written in lua.

**Screenshot**

![undotree](./screenshot/undotree.png)

### Download and Install

Using Vim's built-in package manager:

```sh
mkdir -p ~/.config/nvim/pack/github/start/
cd ~/.config/nvim/pack/github/start/
git clone https://github.com/jiaoshijie/undotree.git
```

Using [vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'jiaoshijie/undotree'
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```
use { "jiaoshijie/undotree" }
```

### Usage

1. Use `UndotreeToggle` to toggle the undo-tree panel. You may want to map this command to whatever hotkey by adding the following line to your vimrc, take `<leader>u` for example.

```
" vimscript
nnoremap <leader>u :UndotreeToggle<cr>

-- lua
vim.api.nvim_set_keymap('n', '<leader>u', ':UndotreeToggle', {noremap = true})
```

2. Some Mappings

| Mappings | Action                                                               |
| ----     | ----                                                                 |
| `j`      | jump to next undo node                                               |
| `k`      | jump to prev undo node                                               |
| `Q`      | quit undotree                                                        |
| `q`      | close undotree diff window                                           |
| `J`      | jump to next undo node and undo to this state                        |
| `K`      | jump to prev undo node and undo to this state                        |
| `p`      | show the undotree diff window if it has been shown then jump into it |
| `<cr>`   | undo to this state                                                   |


### License

**MIT**

## Reference

- [how to write a neovim plugin in lua](https://dev.to/2nit/how-to-write-neovim-plugins-in-lua-5cca)
- [undotree](https://github.com/mbbill/undotree)
- [vim-mundo](https://github.com/simnalamburt/vim-mundo)
- [Vim documentation: usr_32](http://vimdoc.sourceforge.net/htmldoc/usr_32.html)
- [how is the undo tree used in vim](https://stackoverflow.com/questions/1088864/how-is-the-undo-tree-used-in-vim)
- [Undo branching and Gundo.vim](http://vimcasts.org/episodes/undo-branching-and-gundo-vim/)
- [Using undo branches](https://vim.fandom.com/wiki/Using_undo_branches)
