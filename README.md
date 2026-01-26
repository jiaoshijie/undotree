# undotree

This plugin is primarily a visualizer for Neovim’s internal undo tree.
All undo-related functionality is provided by Neovim itself.
See `:h undo.txt` and `:h undolevels` for more details.

## Tree Style

| Legacy | Compact |
| :---:  |  :---:  |
| ![legacy](https://i.imgur.com/pwKpOGb.png) | ![compact](https://i.imgur.com/EebI5Cd.png) |

## Requirements

- nvim 0.11.0 or above

## Features

1. Visualizes Neovim’s internal undo tree structure
2. Diff preview between the current undo state and the state under the cursor
3. Commands for clearing undo history and renaming file
4. Two tree styles
5. Multiple window layouts
6. Self-contained lazy loading

## Non-Features

- Live update while editing the file
- Multiple undotree instances

I think it a bit odd to keep undotree open while editing. The plugin is designed
for when you want to undo/redo to or copy something from a state outside your
current branch, you open the tree, do the operation, and then close it to continue
editing the file.

## Download and Install

Using Neovim's built-in package manager:

```sh
mkdir -p ~/.config/nvim/pack/github/start/
cd ~/.config/nvim/pack/github/start/
git clone https://github.com/jiaoshijie/undotree.git
```

Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'jiaoshijie/undotree'
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "jiaoshijie/undotree",
  opts = {
    -- your options
  },
  keys = { -- load the plugin only when using it's keybinding:
    { "<leader>u", "<cmd>lua require('undotree').toggle()<cr>" },
  },
}
```

## Usage

> [!NOTE]
> If you’re fine with the default settings, you don’t need to call the setup
> function — only the keymaps or user commands need to be configured.

### Configuration

Configuration can be passed to the setup function.
Here is an example with the default settings:

```lua
require('undotree').setup({
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

    ignore_filetype = {},
    --- @type "compact" | "legacy"
    parser = "compact",

    keymaps = {
        ["j"] = "move_next",
        ["k"] = "move_prev",
        ["gj"] = "move2parent",
        ["J"] = "move_change_next",
        ["K"] = "move_change_prev",
        ["<cr>"] = "action_enter",
        ["p"] = "enter_diffbuf", -- this can switch between preview and undotree window
        ["q"] = "quit",
        ["S"] = "update_undotree_view",
    },
})
```

### Keymaps

You can directly use `:lua require('undotree').toggle()` for toggling undotree panel,
or set the following keymaps for convenient using:

```lua
vim.keymap.set('n', '<leader>u', require('undotree').toggle, { noremap = true, silent = true })

-- or
vim.keymap.set('n', '<leader>uo', require('undotree').open, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>uc', require('undotree').close, { noremap = true, silent = true })
```

### User Commands

Or if you want to use user command, the following code snippet creates an
`Undotree <subcommand>` command with three options: `toggle`, `open` and `close`.

```lua
vim.api.nvim_create_user_command('Undotree', function(opts)
    local args = opts.fargs
    local cmd = args[1]

    local cb = require("undotree")[cmd]

    if cmd == "setup" or cb == nil then
        vim.notify("Invalid subcommand: " .. (cmd or ""), vim.log.levels.ERROR)
    else
        cb()
    end
end, {
    nargs = 1,
    complete = function(arg_lead)
        return vim.tbl_filter(function(cmd)
            return vim.startswith(cmd, arg_lead)
        end, { "toggle", "open", "close" })
    end,
    desc = "Undotree command with subcommands: toggle, open, close",
})
```

### Undotree Buffer Interface

#### Default Keymaps

| Mappings | Action                                           |
| :----:   | :----:                                           |
| `j`      | Move cursor to next undo node                    |
| `k`      | Move cursor to previous undo node                |
| `gj`     | Jump to the parent of the current node           |
| `J`      | Move to next node and apply that state           |
| `K`      | Move to previous node and apply that state       |
| `Enter`  | Undo to this state                               |
| `p`      | Switch focus between undotree and preview window |
| `q`      | Quit undotree (also works in preview window)     |
| `S`      | Force re-parse of Neovim's internal undo history |

#### Two User Commands

> [!CAUTION]
> These commands are local to the undotree buffer, not the file buffer,
> but the operations are performed on the file buffer.

- `UndotreeClearHistory`: Clear the entire in-memory undo history
  + To persist this change, write the buffer to disk with `:w`; Neovim will clear
    the undo file on disk.
  + To discard this change, delete the buffer without writing and reopen the file.
- `UndotreeRename`: Rename the file while preserving undo history
  + The target path may be either a filename or a directory (like `mv`).
  + If the target file already exists, you will be asked to confirm the overwrite.

## Bug Reports

Bug reports are welcome.

If you encounter a parser bug:

- Please include a screenshot showing how the undotree ascii graph is rendered.
- If you are able to share the file:
  - Use `:wundo {file_name}.undo` to generate the undo file.
  - Attach both the file and its undo file to the issue.
- If you are not able to share the file:
  - Run `:echo undotree()` and include the output (Neovim’s internal undo tree table) in the issue.

## License

**MIT**
