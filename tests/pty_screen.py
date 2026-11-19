import os, pty, time, select, re, sys
import pyte

CONF = os.environ.get("INIT", "/workspace/dev/md-bullets.nvim/tests/dev-alone.lua")
CMD = os.environ.get("NVIM_BIN", "nvim")
KEYS = os.environ.get("KEYS", "")

screen = pyte.Screen(80, 24)
screen.reset()
stream = pyte.ByteStream(screen)

pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.environ["MD_BULLETS_DEBUG"] = os.environ.get("MD_BULLETS_DEBUG", "")
    os.execvp(CMD, [CMD, "-u", CONF, "-c", "set noswapfile",
                    "/workspace/dev/md-bullets.nvim/tests/headings.md"])

def pump(fd, seconds):
    out = b""
    end = time.time() + seconds
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                chunk = os.read(fd, 65536)
                out += chunk
                stream.feed(chunk)
            except OSError:
                break
    return out

pump(fd, 3.0)                          # initial draw
time.sleep(0.5)
if KEYS:
    os.write(fd, KEYS.encode())
time.sleep(0.3)
pump(fd, 2.5)

os.write(fd, b"\x1b")                  # leave any mode
os.write(fd, b":q!\n")
pump(fd, 0.5)

for i, line in enumerate(screen.display):
    if line.strip():
        print(f"{i+1:2d} |{line.rstrip()}|")
