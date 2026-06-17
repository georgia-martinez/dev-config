# dev-config

Personal development environment, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level directory is a stow "package" whose contents mirror paths under `$HOME`.

| Package | Links to | What it is |
|---------|----------|------------|
| `nvim/` | `~/.config/nvim` | Neovim config (LazyVim) |
| `tmux/` | `~/.config/tmux/tmux.conf` | tmux config |
| `bin/`  | `~/.local/bin/dev` | `dev` — the project launcher |

## Prerequisites

- [tmux](https://github.com/tmux/tmux) (`brew install tmux`)
- [Neovim](https://neovim.io) (`brew install neovim`)
- [GNU Stow](https://www.gnu.org/software/stow/) (`brew install stow`)
- [Claude Code](https://claude.com/claude-code) on your `PATH` (`claude`)
- `~/.local/bin` on your `PATH`

## Install

Clone into `~/Repos` (the stow target is your home directory), then stow the packages:

```bash
git clone <repo-url> ~/Repos/dev-config
cd ~/Repos/dev-config
stow -v --target="$HOME" nvim tmux bin
```

> **Note:** Always pass `--target="$HOME"`. Because the repo lives in `~/Repos`,
> stow's default target would incorrectly link files into `~/Repos`.

To add a single package later: `stow -v --target="$HOME" <package>`.
To remove one: `stow -D -v --target="$HOME" <package>`.

## Opening a project

The `dev` command opens a repo in a 3-pane tmux layout — Claude, Neovim, and a
terminal, all started in the same project directory:

```
+-------------------+-------------------+
|                   |                   |
|      claude       |       nvim        |
|                   |                   |
+-------------------+-------------------+
|              terminal                 |
+---------------------------------------+
```

```bash
dev ~/Repos/some-project   # open a specific directory
cd ~/Repos/some-project && dev   # ...or just `dev` in the current directory
```

What it does:

- Creates a tmux session named after the directory.
- Launches `claude` (left), `nvim` (right), and leaves a shell (bottom).
- Attaches you to the session (or switches, if you're already in tmux).
- **Re-running `dev` on the same project re-attaches** to the existing session
  instead of rebuilding it — so it doubles as "jump back into project X."

### Why the panes "reference each other"

All three panes share the same working directory, so Claude, Neovim, and the
shell operate on the same files. The tmux config enables `focus-events`, which
(together with LazyVim's `autoread`) makes Neovim **auto-reload files that Claude
edits** when you switch back to the nvim pane — no manual `:e` needed.

A typical loop: ask Claude (left) for a change → see it reload in nvim (right) →
run tests in the terminal (bottom) → feed results back to Claude.

## tmux cheatsheet

The prefix is the default `Ctrl-b`.

| Keys | Action |
|------|--------|
| `Ctrl-b` then `h` / `j` / `k` / `l` | Move between panes (vi-style) |
| mouse click / scroll / drag | Select, scroll, resize panes |
| `Ctrl-b` then `\|` | Split pane vertically (inherits cwd) |
| `Ctrl-b` then `-` | Split pane horizontally (inherits cwd) |
| `Ctrl-b` then `r` | Reload `tmux.conf` |
| `Ctrl-b` then `d` | Detach (session keeps running; `dev` re-attaches) |

After editing `tmux.conf`, reload a running session with `Ctrl-b` then
`:source-file ~/.config/tmux/tmux.conf`, or start a fresh session.
