import os
src = open("pty_screen.py").read()
src = src.replace("/workspace/dev/md-bullets.nvim/tests/headings.md", os.environ.get("TARGET", "/workspace/dev/md-bullets.nvim/tests/headings.md"))
exec(src)
