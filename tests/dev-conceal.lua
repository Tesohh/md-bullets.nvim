local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.o.runtimepath = root .. ',' .. vim.o.runtimepath
require('md-bullets').setup { concealcursor = true }
