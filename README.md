# md-bullets.nvim

Replicates the behaviour of [org-bullets.nvim](https://github.com/nvim-orgmode/org-bullets.nvim) for markdown.

Heading markers (`#`) are hidden and replaced by a configurable unicode bullet.
The bullet is cycled by heading level, for example `◉`, `○`, `✸`, `✿`.
The leading `#` characters are only shown again on the line under the cursor.

Built with `nvim_set_decoration_provider` and ephemeral extmarks. No treesitter
parser is required.

## Requirements

- Neovim 0.7+

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "you/md-bullets.nvim",
  ft = "markdown",
  config = function()
    require("md-bullets").setup()
  end,
}
```

Or with packer.nvim:

```lua
use { "you/md-bullets.nvim", config = function()
  require("md-bullets").setup()
end }
```

## Configuration

```lua
require("md-bullets").setup {
  -- Bullet characters, cycled by heading level
  -- Can also be a function that receives the default list, e.g.
  --   bullets = function(defaults) return vim.list_extend(defaults, {"x"}) end
  bullets = { "◉", "○", "✸", "✿" },
  -- true always draws the bullet, even under the cursor; false (default)
  -- shows the raw '#' markers only while the cursor is on them
  concealcursor = false,
}
```

Each entry in `bullets` can also be a `{ "◉", "HighlightGroup" }` tuple to give
a level its own highlight group.

Highlights default to the matching markdown treesitter groups:

```lua
vim.api.nvim_set_hl(0, "MdBulletsBullet1", { link = "Title", default = true })
```

## How it works

Per redraw, every visible markdown heading line gets one ephemeral overlay
extmark per `#` character: the leading markers are covered with spaces and the
last one carries the level's bullet. The marker text itself is never modified,
and column positions stay stable, so it composes with indent plugins such as
md-indent.nvim.

The raw `#` markers only show while the cursor is on one of the `#` glyphs of
that line; the moment it moves onto the text, the bullet comes back. Cursor
moves do not invalidate the window on their own, so the plugin redraws the
cursor line itself via `nvim__redraw` (Nvim 0.10+) on every move.

Pairing with [md-indent.nvim](https://github.com/you/md-indent.nvim) works out
of the box: that plugin owns indentation, this one only swaps the glyphs.

## Notes

- Set `concealcursor = true` to keep bullets drawn on the cursor line too.
