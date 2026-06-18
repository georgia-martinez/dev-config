# dev-config

Personal development environment, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level directory is a stow "package" whose contents mirror paths under `$HOME`.

| Package | Links to | What it is |
|---------|----------|------------|
| `nvim/`   | `~/.config/nvim`   | Neovim config (LazyVim) |
| `tmux/`   | `~/.config/tmux`   | tmux config (`tmux.conf` + `term.conf` for the terminal tabs) |
| `bin/`    | `~/.local/bin/dev` | `dev` — the project launcher |
| `claude/` | `~/.claude/statusline-command.sh` | Claude Code status-line renderer (usage bars) |

## Prerequisites

- [tmux](https://github.com/tmux/tmux) (`brew install tmux`)
- [Neovim](https://neovim.io) (`brew install neovim`)
- [GNU Stow](https://www.gnu.org/software/stow/) (`brew install stow`)
- [Claude Code](https://claude.com/claude-code) on your `PATH` (`claude`)
- `~/.local/bin` on your `PATH`

For the optional Claude usage status line (see below):

- [`jq`](https://jqlang.github.io/jq/) (`brew install jq`)
- [`llm-quota`](https://github.com/robbell5/llm-quota) (`go install github.com/robbell5/llm-quota/cmd/llm-quota@latest`)

## Install

Clone into `~/Repos` (the stow target is your home directory), then stow the packages:

```bash
git clone <repo-url> ~/Repos/dev-config
cd ~/Repos/dev-config
stow -v --target="$HOME" nvim tmux bin claude
```

> **Note:** Always pass `--target="$HOME"`. Because the repo lives in `~/Repos`,
> stow's default target would incorrectly link files into `~/Repos`.

To add a single package later: `stow -v --target="$HOME" <package>`.
To remove one: `stow -D -v --target="$HOME" <package>`.

You only need to **re-stow when files are added, renamed, or removed** from a
package — editing the contents of an already-linked file takes effect
immediately (the file in `$HOME` is a symlink straight into the repo).

## Opening a project

The `dev` command opens a repo in a 3-pane tmux layout — Claude on a full-height
left column, Neovim top-right, and a terminal bottom-right, all started in the
same project directory:

```
+----------+--------------------------+
|          |           nvim           |
|          |                          |
|  claude  +--------------------------+
|          |     terminal (tabbed)    |
+----------+--------------------------+
```

```bash
dev ~/Repos/some-project   # open a specific directory
cd ~/Repos/some-project && dev   # ...or just `dev` in the current directory
```

What it does:

- Creates a tmux session named after the directory, sized to the current terminal.
- Launches `claude --continue` (left, ~30% width) — **resumes the most recent
  Claude conversation for that project**, or starts fresh if there isn't one.
- Launches `nvim .` (top-right) — opens Neovim rooted at the project.
- Launches a **nested tmux** in the terminal pane (bottom-right) for
  VS Code-style switchable terminal tabs — see [Terminal tabs](#terminal-tabs).
- Attaches you to the session (or switches, if you're already in tmux).
- **Re-running `dev` on the same project re-attaches** to the existing session
  instead of rebuilding it — so it doubles as "jump back into project X."

### Why the panes "reference each other"

All three panes share the same working directory, so Claude, Neovim, and the
shell operate on the same files. The tmux config enables `focus-events`, which
(together with LazyVim's `autoread`) makes Neovim **auto-reload files that Claude
edits** when you switch back to the nvim pane — no manual `:e` needed.

A typical loop: ask Claude (left) for a change → see it reload in nvim (top-right)
→ run tests in the terminal (bottom-right) → feed results back to Claude.

## tmux cheatsheet

Two tmux layers are in play, each with its own prefix:

- **Layout** (the `dev` window: Claude / nvim / terminal) — prefix **`Ctrl-b`**.
- **Terminal tabs** (the nested tmux inside the terminal pane) — prefix **`Ctrl-a`**.

### Layout — prefix `Ctrl-b`

| Keys | Action |
|------|--------|
| `Ctrl-b` then `h` / `j` / `k` / `l` | Move between panes (vi-style) |
| mouse click / scroll / drag | Select, scroll, resize panes |
| `Ctrl-b` then `\|` | Split pane vertically (inherits cwd) |
| `Ctrl-b` then `-` | Split pane horizontally (inherits cwd) |
| `Ctrl-b` then `r` | Reload `tmux.conf` |
| `Ctrl-b` then `d` | Detach (session keeps running; `dev` re-attaches) |

### Terminal tabs

The terminal pane runs its own nested tmux, so each terminal is a switchable
"tab" shown in the bar at the top of the pane. **Focus the terminal pane first**
(`Ctrl-b` then `l`/`j`), then the prefix is **`Ctrl-a`**:

| Keys | Action |
|------|--------|
| `Ctrl-a` then `1` … `9` | Jump to tab N |
| `Ctrl-a` then `c` | New tab |
| `Ctrl-a` then `n` / `p` | Next / previous tab |
| `Ctrl-a` then `,` | Rename the current tab |
| `Ctrl-a` then `&` | Close the current tab (asks y/n) |
| click a tab in the bar | Switch to it |
| type `exit` (or `Ctrl-d`) | Close the current tab's shell |

No-prefix shortcuts (require "Option as Meta" in your terminal; the `Ctrl-a`
versions always work):

| Keys | Action |
|------|--------|
| `Alt-t` | New tab |
| `Alt-h` / `Alt-l` | Previous / next tab |
| `Alt-w` | Close the current tab (asks y/n) |

The nested tmux runs on its own socket (`-L devterm`) with one session per
project, so its tabs persist across re-opens. If it's ever killed or exited, the
pane falls back to a plain shell instead of disappearing.

After editing `tmux.conf`, reload a running session with `Ctrl-b` then
`:source-file ~/.config/tmux/tmux.conf`, or start a fresh session. The terminal
tabs read `term.conf` only when a nested tmux first starts, so changes there take
effect on the next freshly-opened `dev` session.

## Claude usage status line (optional)

The `claude/` package provides `statusline-command.sh`, a renderer that draws
colored bars for context-window, 5-hour, and 7-day rate-limit usage at the bottom
of the Claude pane. It's wired up through `~/.claude/settings.json` (which is
**not** stowed — configure it directly):

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/go/bin/llm-quota claude-statusline-cache-writer --cache ~/.cache/llm-quota/claude.json --passthrough ~/.claude/statusline-command.sh"
  }
}
```

[`llm-quota`](https://github.com/robbell5/llm-quota) wraps the renderer: it runs
it unchanged (`--passthrough`) while caching the usage numbers to
`~/.cache/llm-quota/claude.json`. The bars need `jq`; the wrapper needs the
`llm-quota` binary (see [Prerequisites](#prerequisites)). Rate-limit data appears
on Pro/Max plans after the first API response in a session.
