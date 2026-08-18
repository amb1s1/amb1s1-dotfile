# Dotfiles

![](https://img.shields.io/badge/works%20on-macOS-D376B3.svg)
![](https://img.shields.io/badge/works%20on-Linux-DD4814.svg)

Shell, tmux and git, set up the same way on macOS and Linux, plus a
macOS desktop layer (tiling WM, key remapping, text expansion). One script, one
set of configs, no framework.

Shells differ by platform on purpose: **fish on macOS** (interactive), **zsh on
Linux**, with **bash** as the login shell everywhere — ssh, cron, launchd, git
hooks. They share `gitconfig` and `tmux.conf`; `starship.toml` is used by bash
and zsh, so it is what you get over ssh.

fish is the macOS default for one concrete reason: it is the only one of the
three candidates where <kbd>Ctrl</kbd>+<kbd>r</kbd> reaches atuin in **every**
editing mode; bash covers only two of its three keymaps — see invariant 4. bash
remains a one-line rollback in `configs/ghostty`.

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
3. On Linux, clone the three zsh plugins.
4. Scaffold the untracked machine-specific files and install a `gitleaks`
   pre-commit hook.
5. Symlink every config — portable ones everywhere, macOS ones only on macOS.
6. Set the login shell: Homebrew bash on macOS, zsh on Linux.

Re-running the script is safe:
any real file it would replace is moved into a timestamped `.backup-<stamp>/`
directory first — one per run, so re-running can never overwrite an earlier
backup — and anything already correctly linked is left alone.

| Flag | Effect |
| --- | --- |
| `--dry-run` | Print every action, change nothing. CI asserts this is genuinely inert. |
| `--no-packages` | Link configs only; skip all package installs. |

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
| **zoxide** | `cd` | Jumps to directories by frecency via `z` / `zi`; `cd` is left alone |
| **fd** | `find` | Sane defaults, respects gitignore |
| **ripgrep** | `ag` | Faster, and what fzf searches with |
| **bat** | `cat` | Syntax highlighting and paging |
| **delta** | `git diff` output | Side-by-side, syntax-highlighted diffs |
| **fzf** + **fzf-tab** | ctrl-p, tab completion | Fuzzy history, files and completion menus |
| **uv** + **ruff** | pip, pyenv, black, flake8 | One Python toolchain, one linter/formatter |

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
| `configs/ghostty` | `~/.config/ghostty/config` | Terminal — theme, and where the interactive shell is launched |
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

> **Do not use `git config --global` on this machine.** `~/.gitconfig` is a
> symlink into this repo, so `--global` writes work emails and internal URL
> rewrites straight into a tracked, public file. Edit `~/.gitconfig.local`
> instead, or use `git config --file ~/.gitconfig.local`. The denylist check and
> the pre-commit hook both catch it, but only after you have already written it.

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
| **Interactive** | [fish](https://fishshell.com), launched by Ghostty | zsh + three plugins |
| **Login / system** | Homebrew bash 5.x | zsh |
| **Config** | `~/.config/fish/` (untracked, see below) | `configs/zshrc` |

fish is the interactive shell because it is the only candidate where
<kbd>Ctrl</kbd>+<kbd>r</kbd> reaches atuin in every editing mode — see invariant
4. bash stays the login and system shell (ssh, cron, launchd, git hooks,
Hammerspoon's `hs.execute()`) and reads `configs/bashrc`, which is deliberately
plain: no line-editor layer, because bash is almost never interactive here.

**`configs/bashrc` and `configs/starship.toml` still matter** — they are what you
get over ssh, and on Linux. The prompt work lives there, not in fish.

**Known gap:** fish's own config is **not tracked in this repo.** `~/.config/fish/`
holds a hand-written prompt and machine-specific paths, so a fresh Mac gets fish
with no configuration. Tracking it needs the same sanitising treatment as
everything else here and has not been done yet.

zsh is untouched on Linux and `configs/zshrc` is still maintained for it; the
shells coexist rather than one replacing the other.

### Rollback

Off fish — one line in `configs/ghostty` (and set `shell-integration = bash`):

```
command = /opt/homebrew/bin/bash --login
```

bash is already the login shell, so that is the only edit. Note the trade-off in
invariant 4: under bash, atuin does not bind <kbd>Ctrl</kbd>+<kbd>r</kbd> in vi
normal mode, so `configs/bashrc` rebinds it explicitly.

## macOS desktop layer

One tool per job, and the tool whose config is text wins.

| Job | Owner | Config |
| --- | --- | --- |
| Key remapping | Karabiner + goku | `configs/karabiner.edn` |
| Text expansion everywhere | espanso | `configs/espanso/match/*.yml` |
| Shell history search | atuin | `configs/atuin.toml` |
| **System events** | **Hammerspoon** | `configs/hammerspoon/` |
| GUI-only app prefs | `defaults` snapshots | `macos/defaults.sh` (output untracked) |

Hammerspoon is deliberately the smallest piece. Window management is plain
macOS. What Hammerspoon owns is the category nothing else exposes: reacting to
macOS system events.

- `modules/wifi.lua` — SSID change → classify network trust zone
- `modules/camera.lua` — camera starts/stops → on-screen "on air" alert
- `modules/power.lua` — sleep/wake → eject disks
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

1. **Accessibility + Input Monitoring** for Hammerspoon, Karabiner-Elements and
   espanso → System Settings ▸ Privacy & Security
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
reasonable-looking cleanup breaks them and nothing tells you. `doctor.sh` asserts
every one; the rationale is commented at the point of use. Four of the six are
pure repo-content checks, so `doctor.sh --static` catches them in CI before a
change is ever installed; #4 (Ghostty's second config) and #5 (generated
`karabiner.json`) need a real machine.

Each assertion has been verified to actually fail when the invariant is broken —
a check that cannot fail is worse than no check, because it reads as coverage.
Invariant 6 is the cautionary example: the original render-and-check-stderr test
passed on a genuinely broken config, because a module starship never evaluates
never complains. It is now checked two ways, one of which needs neither starship
nor a git repo.

1. **PATH is set above the interactive guard in `bashrc`.** Below it, every
   non-interactive shell — `hs.execute()`, launchd, cron, git hooks — gets no
   PATH. The classic "works in my terminal, not from the app" bug.
2. **In `bashrc`, starship is initialised before atuin.** Bash has no native
   preexec hook, so both compete for `PROMPT_COMMAND` and the DEBUG trap. atuin
   first can clobber starship's `PROMPT_COMMAND`.
3. **<kbd>Ctrl</kbd>+<kbd>r</kbd> must reach atuin, and only fish manages it in
   every mode.** Recording history and *searching* it are separate capabilities.
   Every atuin assertion here used to prove only recording, which is how this
   went unnoticed on a machine that looked healthy:

   - **fish** has a first-class atuin backend and binds it in every mode. This is
     why fish is the interactive shell.
   - **bash** binds it in `emacs` and `vi-insert`, but atuin deliberately skips
     `vi-command` to preserve a line editor's `redo`. fzf then claims that slot,
     and fzf's widget reads bash's `builtin history` — dozens of lines — not
     atuin's thousands. In vi mode <kbd>Ctrl</kbd>+<kbd>r</kbd> silently means two
     different things depending on the mode, and the normal-mode one looks exactly
     like lost history. `configs/bashrc` rebinds it explicitly.
   - **brush** (removed) could not bind it at all: it drives its line editor with
     reedline, not GNU readline, and its `bind` builtin accepted a binding then
     registered nothing — `bind -p` printed zero lines where bash prints 422.

   `doctor.sh` reports which mechanism applies rather than assuming readline. It
   cannot prove the live binding from a script: a non-interactive shell engages no
   line editor. Check by hand, in the shell: `bind -p | grep C-r`.
4. **Ghostty reads *two* config files on macOS, and the other one wins.** Besides
   `~/.config/ghostty/config` it reads
   `~/Library/Application Support/com.mitchellh.ghostty/config`, whose scalars
   override the repo's — while list-valued keys like `font-family` accumulate from
   both. Ghostty writes a template there on first launch, so it exists whether or
   not you put it there. A stale one silently set `command` and `theme`, so the
   repo's shell and palette were inert for weeks while every repo-content check
   passed. **Reading `configs/ghostty` proves intent, not reality** — `doctor.sh`
   asks `ghostty +show-config` what was actually resolved and compares it against
   the repo, including that `shell-integration` names the same shell as `command`.
5. **`karabiner.json` is generated, never tracked.** Karabiner replaces a
   symlinked JSON with a real file. `karabiner.edn` is the source; `goku`
   compiles it; `.gitignore` excludes the output. Two traps: goku needs a profile
   named exactly `Default` (Karabiner creates `"Default profile"`), and `goku`
   exits 1 even on success, so its exit status cannot gate anything — test its
   `--dry-run` stdout instead.
6. **In `starship.toml`, literal `(` and `$` must be escaped** — `[\(](dim)` and
   `[\$](cyan)`. Unescaped, starship reads `(` as a conditional group and `$` as
   the start of a variable name, and the module or indicator silently renders
   **nothing**. TOML parsing will not reveal it, and neither will
   `starship prompt` unless the module actually evaluates: `git_branch` needs a
   git repo, and `git_status.stashed` needs a repo **with a stash**. `stashed`
   shipped broken for exactly that reason, so both are also checked statically.

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

<kbd>Ctrl</kbd> + <kbd>h/j/k/l</kbd> moves between tmux panes.
Copying with <kbd>y</kbd> goes to the system clipboard via `pbcopy` on macOS and
`wl-copy` or `xclip` on Linux — install one of those on Linux for clipboard
integration.

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
each tool is wired up only if installed, and git falls back to `less` when delta
is missing.
