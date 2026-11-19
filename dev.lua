-- Dev init for trying the plugin together with the sibling md-indent.nvim.
-- Works on Nvim 0.7+. Run with:
--   nvim -u /workspace/dev/md-bullets.nvim/dev.lua some_file.md

-- Root of this repo, resolved from this script's own path
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local sibling = vim.fn.fnamemodify(root, ":h") .. "/md-indent.nvim"

if vim.fn.isdirectory(sibling) == 1 then
	vim.o.runtimepath = root .. "," .. sibling .. "," .. vim.o.runtimepath
else
	vim.notify("md-indent.nvim not found at " .. sibling, vim.log.levels.WARN)
end

-- md-bullets: hide the '#' of headings behind a rotating bullet
require("md-bullets").setup({
	bullets = { "◉", "○", "✸", "✿" },
	concealcursor = false,
})

-- md-indent: indent markdown lines under their heading level
vim.g.md_indent_setup = { setext_headings = true }
require("md-indent").setup()
