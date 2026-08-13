# Dotfiles

![](https://img.shields.io/badge/works%20on-macOS-D376B3.svg)
![](https://img.shields.io/badge/works%20on-Linux-DD4814.svg)

My zsh, tmux, neovim and editorconfig setup. One script, one set of configs,
same behaviour on macOS and Linux.

## Install

```sh
git clone https://github.com/amb1s1/amb1s1-dotfile.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

That will:

1. Install `git`, `zsh`, `tmux`, `neovim`, `curl`, `fzf`, `ripgrep` and `bat`
   using whichever package manager is present — Homebrew, apt, dnf or pacman.
   On macOS it installs Homebrew first if it is missing.
2. Install oh-my-zsh plus the autosuggestions and syntax-highlighting plugins.
3. Symlink the configs into your home directory.
4. Make zsh your default shell.

Neovim installs vim-plug and all its plugins by itself the first time you
open it.

Re-running the script is safe. Any real file it would replace is moved to
`<name>.backup` first, and everything already in place is left alone. Use
`./install.sh --no-packages` to only link configs and skip package installs.

## What gets linked

| Repo file                | Symlinked to            |
| ------------------------ | ----------------------- |
| `configs/zshrc`          | `~/.zshrc`              |
| `configs/tmux.conf`      | `~/.tmux.conf`          |
| `configs/nvim-init.vim`  | `~/.config/nvim/init.vim` |
| `configs/editorconfig`   | `~/.editorconfig`       |
| `configs/words`          | `~/.words`              |

## Machine-specific settings

Do not edit `configs/zshrc` for one machine. Put work aliases, tokens, proxies
and anything else private in `~/.zshrc.local` — it is sourced last and is not
tracked by this repo.

## tmux

Prefix is <kbd>Ctrl</kbd> + <kbd>a</kbd>.

| Action                    | Binding                                                     |
| ------------------------- | ----------------------------------------------------------- |
| Split vertically          | <kbd>Prefix</kbd> <kbd>\\</kbd>                             |
| Split horizontally        | <kbd>Prefix</kbd> <kbd>-</kbd>                              |
| Move between panes        | <kbd>Ctrl</kbd> + <kbd>h</kbd>/<kbd>j</kbd>/<kbd>k</kbd>/<kbd>l</kbd> |
| Resize pane               | <kbd>Prefix</kbd> <kbd>H</kbd>/<kbd>J</kbd>/<kbd>K</kbd>/<kbd>L</kbd> |
| Copy mode (vi keys)       | <kbd>Prefix</kbd> <kbd>Enter</kbd>, then <kbd>v</kbd> to select and <kbd>y</kbd> to copy |
| Reload config             | <kbd>Prefix</kbd> <kbd>r</kbd>                              |

<kbd>Ctrl</kbd> + <kbd>h/j/k/l</kbd> moves between tmux panes and vim splits
alike. Copying with <kbd>y</kbd> goes to the system clipboard, using `pbcopy`
on macOS and `wl-copy` or `xclip` on Linux — install one of those on Linux if
you want clipboard integration.

## Neovim

Leader key is <kbd>,</kbd>.

| Action                                 | Binding                          |
| -------------------------------------- | -------------------------------- |
| Toggle file tree                       | <kbd>Ctrl</kbd> + <kbd>n</kbd>   |
| Find files                             | <kbd>Ctrl</kbd> + <kbd>p</kbd>   |
| Search file contents (ripgrep)         | <kbd>Ctrl</kbd> + <kbd>f</kbd>   |
| Switch buffer                          | <kbd>Leader</kbd> <kbd>b</kbd>   |
| Replace the word under the cursor      | <kbd>Leader</kbd> <kbd>s</kbd>   |
| Clear search highlight                 | <kbd>Leader</kbd> <kbd>Space</kbd> |
| Comment a line / selection             | `gcc` / `gc`                     |

To update the plugins, run `:PlugUpdate`.

## Terminal font

The status lines use Powerline glyphs, so pick a Nerd Font in your terminal
emulator. Any of them works — for example:

```sh
# macOS
brew install --cask font-hack-nerd-font

# Linux
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
unzip -o Hack.zip && rm Hack.zip && fc-cache -f
```
