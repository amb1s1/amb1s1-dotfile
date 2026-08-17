# Dotfiles

![](https://img.shields.io/badge/works%20on-macOS-D376B3.svg)
![](https://img.shields.io/badge/works%20on-Linux-DD4814.svg)

zsh, tmux, neovim and git, set up the same way on macOS and Linux. One script,
one set of configs, no framework.

## Install

```sh
git clone https://github.com/amb1s1/amb1s1-dotfile.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

That will:

1. Install the tools below with whichever package manager is present —
   Homebrew, apt, dnf or pacman. On macOS it installs Homebrew first if needed.
2. Install anything the distro does not package (starship, uv, ruff) from
   upstream into `~/.local`, so nothing outside the package step needs root.
3. Pull a current neovim if the packaged one is older than 0.11, which is the
   case on Debian and Ubuntu.
4. Clone the three zsh plugins and symlink every config.
5. Make zsh your default shell.

Neovim installs its own plugins on first launch. Re-running the script is safe:
real files it would replace are moved to `<name>.backup` first, and anything
already in place is left alone. `./install.sh --no-packages` links configs only.

## What you get

| Tool | Replaces | Why |
| --- | --- | --- |
| **starship** | oh-my-zsh themes | One binary, one TOML, no framework. Shell starts in ~90ms |
| **eza** | `ls` | Colours, git status, tree mode |
| **zoxide** | `cd` | Jumps to directories by frecency. Aliased over `cd` |
| **fd** | `find` | Sane defaults, respects gitignore |
| **ripgrep** | `ag` | Faster, and what fzf and neovim search with |
| **bat** | `cat` | Syntax highlighting and paging |
| **delta** | `git diff` output | Side-by-side, syntax-highlighted diffs |
| **fzf** + **fzf-tab** | ctrl-p, tab completion | Fuzzy history, files and completion menus |
| **lazygit** | git porcelain | Staging hunks without leaving the terminal |
| **uv** + **ruff** | pip, pyenv, black, flake8 | One Python toolchain, one linter/formatter |
| **btop** | `top` | Readable process and resource view |

## What gets linked

| Repo file | Symlinked to |
| --- | --- |
| `configs/zshrc` | `~/.zshrc` |
| `configs/starship.toml` | `~/.config/starship.toml` |
| `configs/tmux.conf` | `~/.tmux.conf` |
| `configs/nvim-init.lua` | `~/.config/nvim/init.lua` |
| `configs/gitconfig` | `~/.gitconfig` |
| `configs/gitignore_global` | `~/.gitignore_global` |
| `configs/editorconfig` | `~/.editorconfig` |
| `configs/words` | `~/.words` |

## Machine-specific settings

Nothing private belongs in this repo. Two files are sourced last and tracked by
neither git nor the installer:

- `~/.zshrc.local` — work aliases, tokens, proxies, `PATH` additions.
- `~/.gitconfig.local` — your name and email, and any per-machine git settings.
  If you already had a git identity, the installer copies it here for you.

## tmux

Prefix is <kbd>Ctrl</kbd> + <kbd>a</kbd>.

| Action | Binding |
| --- | --- |
| Split vertically | <kbd>Prefix</kbd> <kbd>\\</kbd> |
| Split horizontally | <kbd>Prefix</kbd> <kbd>-</kbd> |
| Move between panes | <kbd>Ctrl</kbd> + <kbd>h</kbd>/<kbd>j</kbd>/<kbd>k</kbd>/<kbd>l</kbd> |
| Resize pane | <kbd>Prefix</kbd> <kbd>H</kbd>/<kbd>J</kbd>/<kbd>K</kbd>/<kbd>L</kbd> |
| Copy mode | <kbd>Prefix</kbd> <kbd>Enter</kbd>, then <kbd>v</kbd> to select, <kbd>y</kbd> to copy |
| Reload config | <kbd>Prefix</kbd> <kbd>r</kbd> |

<kbd>Ctrl</kbd> + <kbd>h/j/k/l</kbd> crosses tmux panes and neovim splits alike.
Copying with <kbd>y</kbd> goes to the system clipboard via `pbcopy` on macOS and
`wl-copy` or `xclip` on Linux — install one of those on Linux for clipboard
integration.

## Neovim

Leader is <kbd>,</kbd>. Needs neovim 0.11+, which the installer takes care of.

| Action | Binding |
| --- | --- |
| Toggle file tree | <kbd>Ctrl</kbd> + <kbd>n</kbd> |
| Find files | <kbd>Ctrl</kbd> + <kbd>p</kbd> |
| Search file contents | <kbd>Ctrl</kbd> + <kbd>f</kbd> |
| Switch buffer | <kbd>Leader</kbd> <kbd>b</kbd> |
| Search this buffer | <kbd>Leader</kbd> <kbd>/</kbd> |
| Replace word under cursor | <kbd>Leader</kbd> <kbd>s</kbd> |
| Clear search highlight | <kbd>Leader</kbd> <kbd>Space</kbd> |
| Go to definition / references | <kbd>g</kbd><kbd>d</kbd> / <kbd>g</kbd><kbd>r</kbd> |
| Hover docs | <kbd>K</kbd> |
| Rename / code action | <kbd>Leader</kbd> <kbd>rn</kbd> / <kbd>Leader</kbd> <kbd>ca</kbd> |
| Comment line / selection | `gcc` / `gc` (built into neovim) |

Language servers are installed by mason, not by hand — `lua_ls`, `ruff`,
`bashls` and `yamlls` come by default, and `:Mason` adds more. Python files are
formatted with ruff on save. Plugins update with `:Lazy sync`.

The whole config is one commented file, `configs/nvim-init.lua`, so everything
you might want to change is visible in one place.

## Terminal font

The status lines use Powerline glyphs, so pick a Nerd Font in your terminal:

```sh
# macOS
brew install --cask font-hack-nerd-font

# Linux
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
unzip -o Hack.zip && rm Hack.zip && fc-cache -f
```

## Requirements

git 2.35+ for the `zdiff3` conflict style. Everything else degrades quietly:
each tool in `~/.zshrc` is wired up only if installed, and git falls back to
`less` when delta is missing.
