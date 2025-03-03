# undotree

A neovim undotree plugin written in lua.

**Screenshot**

![preview](https://user-images.githubusercontent.com/43605101/232043141-f4318a13-8a85-41ee-bbb5-6f86511b32fe.png)

Diff previewer window shows the difference between the current node and the node under the cursor.

### Requirements

- nvim 0.7.0 or above

### Download and Install

Using Vim's built-in package manager:

```sh
mkdir -p ~/.config/nvim/pack/github/start/
cd ~/.config/nvim/pack/github/start/
git clone https://github.com/nvim-lua/plenary.nvim.git
git clone https://github.com/jiaoshijie/undotree.git
```

Using [vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'nvim-lua/plenary.nvim'
Plug 'jiaoshijie/undotree'
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "jiaoshijie/undotree",
  requires = {
    "nvim-lua/plenary.nvim",
  },
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "jiaoshijie/undotree",
  dependencies = "nvim-lua/plenary.nvim",
  config = true,
  keys = { -- load the plugin only when using it's keybinding:
    { "<leader>u", "<cmd>lua require('undotree').toggle()<cr>" },
  },
}
```

### Usage

Basic setup

```lua
require('undotree').setup()
```

If using [packer.nvim](https://github.com/wbthomason/packer.nvim) undotree can be setup directly in the plugin spec:

```lua
use {
  "jiaoshijie/undotree",
  config = function()
    require('undotree').setup()
  end,
  requires = {
    "nvim-lua/plenary.nvim",
  },
}
```

Configuration can be passed to the setup function. Here is an example with the default settings:

```lua
local undotree = require('undotree')

undotree.setup({
  float_diff = true,  -- using float window previews diff, set this `true` will disable layout option
  layout = "left_bottom", -- "left_bottom", "left_left_bottom"
  position = "left", -- "right", "bottom"
  ignore_filetype = { 'undotree', 'undotreeDiff', 'qf', 'TelescopePrompt', 'spectre_panel', 'tsplayground' },
  window = {
    winblend = 30,
  },
  keymaps = {
      undotree = {
          ['j'] = "move_next",
          ['k'] = "move_prev",
          ['gj'] = "move2parent",
          ['J'] = "move_change_next",
          ['K'] = "move_change_prev",
          ['<cr>'] = "action_enter",
          ['p'] = "enter_diffbuf",
          ['q'] = "quit",
      },
      undotreeDiff = {
          ['q'] = "quit",
      }
  },
})
```

You can directly use `:lua require('undotree').toggle()` for toggling undotree panel, or set the following keymaps for convenient using.

```lua
vim.keymap.set('n', '<leader>u', require('undotree').toggle, { noremap = true, silent = true })

-- or
vim.keymap.set('n', '<leader>uo', require('undotree').open, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>uc', require('undotree').close, { noremap = true, silent = true })
```

2. Some Mappings

| Mappings         | Action                                               |
| ----             | ----                                                 |
| <kbd>j</kbd>     | jump to next undo node                               |
| <kbd>gj</kbd>    | jump to the parent node of the node under the cursor |
| <kbd>k</kbd>     | jump to prev undo node                               |
| <kbd>J</kbd>     | jump to next undo node and undo to this state        |
| <kbd>K</kbd>     | jump to prev undo node and undo to this state        |
| <kbd>q</kbd>     | quit undotree                                        |
| <kbd>p</kbd>     | jump into the undotree diff window                   |
| <kbd>Enter</kbd> | undo to this state                                   |


### License

**MIT**
