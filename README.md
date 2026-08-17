# Dotfiles

![](https://img.shields.io/badge/works%20on-macOS-D376B3.svg)
![](https://img.shields.io/badge/works%20on-Linux-DD4814.svg)

Shell, tmux, neovim and git, set up the same way on macOS and Linux, plus a
macOS desktop layer (tiling WM, key remapping, text expansion). One script, one
set of configs, no framework.

Shells differ by platform on purpose: **bash + brush on macOS**, **zsh on
Linux**. Both read the same `starship.toml`, `gitconfig` and `tmux.conf`.

## Install

```sh
git clone https://github.com/amb1s1/amb1s1-dotfile.git ~/.dotfiles
cd ~/.dotfiles
./install.sh --dry-run   # read the plan first; changes nothing
./install.sh
./doctor.sh              # verify everything is wired up
```

That will:

1. Install the tools below with whichever package manager is present —
   Homebrew, apt, dnf or pacman. On macOS it installs Homebrew first if needed,
   then applies [`Brewfile`](Brewfile) for the macOS-only layer.
2. Install anything the distro does not package (starship, uv, ruff) from
   upstream into `~/.local`, so nothing outside the package step needs root.
3. Pull a current neovim if the packaged one is older than 0.11, which is the
   case on Debian and Ubuntu.
4. Build ble.sh from a pinned commit (skip with `--no-blesh`).
5. On Linux, clone the three zsh plugins.
6. Scaffold the untracked machine-specific files and install a `gitleaks`
   pre-commit hook.
7. Symlink every config — portable ones everywhere, macOS ones only on macOS.
8. Set the default shell: Homebrew bash on macOS, zsh on Linux.

Neovim installs its own plugins on first launch. Re-running the script is safe:
any real file it would replace is moved into a timestamped `.backup-<stamp>/`
directory first — one per run, so re-running can never overwrite an earlier
backup — and anything already correctly linked is left alone.

| Flag | Effect |
| --- | --- |
| `--dry-run` | Print every action, change nothing. CI asserts this is genuinely inert. |
| `--no-packages` | Link configs only; skip package installs and the ble.sh build. |
| `--no-blesh` | Skip building ble.sh from source. |

`./doctor.sh` is read-only and asserts the things that break silently — see
[Invariants](#invariants-that-break-silently). `./doctor.sh --static` runs only
the checks that read this repo, skipping anything that touches `$HOME` or
installed tools, so it needs neither a Mac nor a linked setup. That is what CI
runs on every push: the invariants live in the script people actually use rather
than in a workflow file that would drift from it.

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

Portable — linked on macOS and Linux alike:

| Repo file | Symlinked to |
| --- | --- |
| `configs/zshrc` | `~/.zshrc` |
| `configs/bashrc` | `~/.bashrc` |
| `configs/bash_profile` | `~/.bash_profile` |
| `configs/inputrc` | `~/.inputrc` |
| `configs/starship.toml` | `~/.config/starship.toml` |
| `configs/tmux.conf` | `~/.tmux.conf` |
| `configs/nvim-init.lua` | `~/.config/nvim/init.lua` |
| `configs/gitconfig` | `~/.gitconfig` |
| `configs/gitignore_global` | `~/.gitignore_global` |
| `configs/editorconfig` | `~/.editorconfig` |
| `configs/words` | `~/.words` |
| `configs/atuin.toml` | `~/.config/atuin/config.toml` |
| `configs/espanso/` | `~/.config/espanso/` |

macOS only — these tools do not exist on Linux, so linking them there would
leave dead config behind:

| Repo file | Symlinked to | What it is |
| --- | --- | --- |
| `configs/brushrc` | `~/.brushrc` | brush-only settings (near-empty by design) |
| `configs/aerospace.toml` | `~/.aerospace.toml` | Tiling WM: workspaces, keybinds, app→workspace rules |
| `configs/ghostty` | `~/.config/ghostty/config` | Terminal — and where brush is launched |
| `configs/karabiner.edn` | `~/.config/karabiner.edn` | Keyboard remapping source; `goku` compiles it |
| `configs/hammerspoon/` | `~/.hammerspoon/` | System event glue only (see below) |
| `macos/defaults.sh` | — | `defaults` snapshots for GUI-only apps + system settings |

## Machine-specific settings

Nothing private belongs in this repo, and this repo is **public**. Config is
tracked; credentials, identity and employer-specific values are not. The tracked
config *references* them; something untracked supplies the value. `install.sh`
scaffolds each of these with a comment explaining what goes in it:

| File | Holds | Read by |
| --- | --- | --- |
| `~/.gitconfig.local` | name, email, work URL rewrites | `configs/gitconfig` `[include]` |
| `~/.config/bash/secrets.sh` | credential values, **mode 600** | `configs/bashrc` |
| `~/.config/bash/local.sh` | work aliases, `PATH` additions, default profiles | `configs/bashrc` |
| `~/.zshrc.local` | the same, for Linux zsh | `configs/zshrc` |
| `~/.config/espanso/match/local.yml` | name, email, internal URLs | espanso |
| `~/.hammerspoon/local.lua` | work hostnames, SSIDs | `urldispatch.lua`, `wifi.lua` |
| `~/.config/dotfiles/denylist` | regexes that must never appear in a tracked file | pre-commit hook, `doctor.sh` |

Four independent defences keep credentials out of git, and all four matter — a
credential in history is the one mistake a normal commit cannot undo:

1. `.gitignore` excludes `secrets.sh`, `local.sh`, `local.lua`, `local.yml`, `*.local`.
2. `install.sh` **refuses to link** if something credential-shaped is sitting in
   `configs/`.
3. The pre-commit hook blocks the commit itself — `gitleaks` for credentials, and
   the denylist for work-internal identifiers in the added lines.
4. `doctor.sh` checks all of the above repo-wide.

### Why the denylist never leaves this machine

`~/.config/dotfiles/denylist` holds your employer's name, internal domains and
account identifiers, so **the patterns are themselves the sensitive material.**
Writing them into a tracked file — or into the CI workflow — would be precisely
the leak they exist to prevent.

Storing them as a `DOTFILES_DENYLIST` Actions secret was considered and
**rejected**. It uploads those identifiers to a third party; anyone able to push a
workflow to the repo can read them back out regardless of the encryption; and on
a public repo secrets are not passed to pull requests from forks, so it would
only ever have covered your own pushes.

The check therefore lives in the **pre-commit hook**, which is the better place
on the merits anyway: it runs before the commit exists, whereas CI can only
report a leak that is already public. CI still runs `gitleaks` and asserts that
no personal application state is tracked — neither of which needs a secret.

`macos/exported/` is gitignored: `macos/defaults.sh export` snapshots GUI app
preferences there so you have a local restore path, but those are personal
prefs with little value to anyone else — and a Raycast dump in particular can
carry more than it appears. Leader Key's `config.json` is untracked for the same
reason (it embeds absolute paths to your own applications); put a copy at
`configs/leaderkey.json` and `install.sh` will link it.

Audit the working tree and history at any time:

```sh
gitleaks dir . --no-banner
```

## Shell

| | macOS | Linux |
| --- | --- | --- |
| **Interactive** | [brush](https://github.com/reubeno/brush), launched by Ghostty | zsh + three plugins |
| **Login / system** | Homebrew bash 5.x | zsh |
| **Config** | `configs/bashrc` (both shells) | `configs/zshrc` |

On macOS, brush and bash read the **same `~/.bashrc`**. brush is a Rust
bash-reimplementation with syntax highlighting and autosuggestions built in, and
it consumes bash config unchanged — it parses `.bashrc` and atuin's init, runs
every alias, `set -o vi`, and every `shopt` used here. bash stays the login and
system shell (ssh, cron, launchd, git hooks, Hammerspoon's `hs.execute()`)
because brush is v0.4: `select` is unsupported and traps/options are still in
progress upstream. That is fine for a terminal window and wrong for launchd.

ble.sh gives bash the fish-like layer (autosuggestions, syntactic highlighting,
vim modes) and is **guarded off under brush**, which supplies its own. It has no
package anywhere, so `install.sh` builds it from a pinned commit — upstream's
newest tag is from 2023 while master is committed to weekly, so a version tag
would pin you to genuinely old code. Skip it with `--no-blesh`.

zsh is untouched on Linux and `configs/zshrc` is still maintained for it; the two
shells coexist rather than one replacing the other.

### Rollback

Off brush — one line in `configs/ghostty`:

```
command = /opt/homebrew/bin/bash --login
```

Nothing else depends on brush, and bash is already the login shell, so that is
the only edit.

## macOS desktop layer

One tool per job, and the tool whose config is text wins.

| Job | Owner | Config |
| --- | --- | --- |
| Window tiling, workspaces | AeroSpace | `configs/aerospace.toml` |
| Key remapping | Karabiner + goku | `configs/karabiner.edn` |
| Text expansion everywhere | espanso | `configs/espanso/match/*.yml` |
| Shell history search | atuin | `configs/atuin.toml` |
| **System events** | **Hammerspoon** | `configs/hammerspoon/` |
| GUI-only app prefs | `defaults` snapshots | `macos/defaults.sh` (output untracked) |

Hammerspoon is deliberately the smallest piece. It does not manage windows —
AeroSpace does that better and declaratively. What Hammerspoon owns is the
category nothing else exposes: reacting to macOS system events.

- `modules/wifi.lua` — SSID change → classify network trust zone
- `modules/camera.lua` — camera in use → focused-window border turns red
- `modules/power.lua` — sleep/wake → eject disks, restore borders
- `modules/usbconsole.lua` — USB serial adapter attached → offer a `picocom` session
- `modules/urldispatch.lua` — route work hostnames to the work browser profile

If a module grows past ~60 lines, ask whether a purpose-built tool should own it.

### On a fresh Mac, run `install.sh` twice

Not a bug — an unavoidable consequence of the approvals below. Karabiner has to
be installed, launched, and **approved by a human** before it writes
`karabiner.json`, and only then can `goku` compile `configs/karabiner.edn` into
it. No single run can cross that boundary, because macOS has no CLI for granting
a driver extension — that is the whole point of the mechanism.

So: run `./install.sh`, grant what it asks for, then run it again. It is
idempotent, and the second pass picks up everything that was gated the first
time. `./doctor.sh` names precisely what is still outstanding, including whether
the driver extension is approved.

### Manual steps macOS will not let a script do

Everything here needs either your password or a click in System Settings. These
four are genuinely unautomatable; anything else the script now handles itself.

1. **Accessibility + Input Monitoring** for Hammerspoon, AeroSpace,
   Karabiner-Elements, espanso → System Settings ▸ Privacy & Security
2. **Karabiner driver extension** → System Settings ▸ General ▸ Login Items &
   Extensions ▸ Driver Extensions ▸ enable Karabiner-Elements. Until this is
   approved Karabiner remaps **nothing** and writes no `karabiner.json`, which
   is why `doctor.sh` checks the state explicitly rather than leaving you to
   infer it from a missing file.
3. **Default browser → Hammerspoon**, only if you want `urldispatch.lua`
4. **Add bash to `/etc/shells` and switch your login shell** — both need your
   password, so `install.sh` prints the two commands rather than running them:
   ```sh
   echo "$(brew --prefix)/bin/bash" | sudo tee -a /etc/shells
   chsh -s "$(brew --prefix)/bin/bash"
   ```

## Invariants that break silently

Each of these was found by testing, and each fails **without any error** — a
reasonable-looking cleanup breaks them and nothing tells you. `doctor.sh`
asserts every one; the rationale is commented at the point of use. Eight of the
ten are pure repo-content checks, so `doctor.sh --static` catches them in CI
before a change is ever installed; the other two (#6 generated `karabiner.json`,
and the live half of #5) need a real machine.

Each assertion has been verified to actually fail when the invariant is broken —
a check that cannot fail is worse than no check, because it reads as coverage.
Invariant 8 is the cautionary example: the original render-and-check-stderr test
passed on a genuinely broken config, because `git_branch` only evaluates inside a
git repository and starship stays silent when a module never runs. It is now
checked two ways, one of which needs neither starship nor a git repo.

1. **PATH is set above the interactive guard in `bashrc`.** Below it, every
   non-interactive shell — `hs.execute()`, launchd, cron, git hooks — gets no
   PATH. The classic "works in my terminal, not from the app" bug.
2. **The ble.sh guard tests `BRUSH_VERSION`, never `BASH_VERSION`.** brush
   deliberately reports `BASH_VERSION=5.2.37`, so a `BASH_VERSION` test matches
   brush and loads ble.sh into the wrong shell.
3. **`bashrc` load order is fixed:** ble.sh (`--attach=none`, first line) →
   starship → atuin → `ble-attach` (last line). Wrong order silently stops atuin
   recording history.
4. **brush launches from Ghostty's `command =` line with two flags**, not
   `chsh` (which cannot pass arguments): `--enable-zsh-hooks` is **required for
   atuin** — without it brush registers `preexec_functions` and never invokes
   them — and `--enable-highlighting` turns on highlighting. bash stays the
   login shell.
5. **No `~/.config/brush/config.toml`.** brush supports one, but the schema is
   undocumented and unknown keys are silently accepted, so a plausible-looking
   config is an invisible no-op. `configs/brushrc` is used instead.
6. **`karabiner.json` is generated, never tracked.** Karabiner replaces a
   symlinked JSON with a real file. `karabiner.edn` is the source; `goku`
   compiles it; `.gitignore` excludes the output.
7. **In `aerospace.toml`, all bindings stay above the `[[on-window-detected]]`
   blocks.** A bare `key = value` after a table array binds to *that table* —
   valid TOML, binding never fires.
8. **In `starship.toml`, literal parens must be escaped** (`[\(](240)`).
   Unescaped, starship reads `(` as a conditional group and the module silently
   renders nothing. TOML parsing will not reveal it, and neither will
   `starship prompt` run outside a git repo — the module has to actually
   evaluate before starship complains.
9. **The brush flag check uses `ps -o command= -p $$`.** Do not simplify it to
   test `preexec_functions` — atuin populates that array whether or not the flag
   is present, so that check always passes.
10. **ble.sh is pinned to a commit SHA**, not a tag (newest tag is 2023; master
    ships weekly).

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
