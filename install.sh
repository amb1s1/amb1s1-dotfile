#!/usr/bin/env bash
# Install these dotfiles on macOS or Linux.
#
#   ./install.sh                everything
#   ./install.sh --no-packages  link configs only
#   ./install.sh --no-blesh     skip building ble.sh from source
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKIP_PACKAGES=false
SKIP_BLESH=false
for arg in "$@"; do
  case "$arg" in
    --no-packages) SKIP_PACKAGES=true ;;
    --no-blesh)    SKIP_BLESH=true ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
is_macos() { [ "$(uname -s)" = "Darwin" ]; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# Package names differ per manager, and not every tool is packaged everywhere.
# Whatever is missing afterwards is picked up by install_missing_tools.
# macOS gets a second layer on top of this — see ./Brewfile.
# gawk is here for ble.sh, whose GNUmakefile refuses to build without GNU awk.
BREW_PKGS=(git zsh bash tmux neovim curl fzf ripgrep bat eza fd git-delta zoxide
           lazygit btop starship uv ruff node stylua shfmt atuin espanso gawk)
APT_PKGS=(git zsh bash tmux neovim curl fzf ripgrep bat fd-find git-delta zoxide
          btop eza nodejs npm shfmt gawk)
DNF_PKGS=(git zsh bash tmux neovim curl fzf ripgrep bat fd-find git-delta zoxide
          btop eza nodejs npm lazygit shfmt gawk)
PACMAN_PKGS=(git zsh bash tmux neovim curl fzf ripgrep bat fd git-delta zoxide
             btop eza nodejs npm lazygit starship uv ruff shfmt atuin gawk)

# ble.sh has no package anywhere and no useful git tag (newest tag: 2023;
# master: committed weekly). Pin a commit so the install is reproducible.
# To advance: pick a new SHA from https://github.com/akinomyoga/ble.sh/commits/master
BLESH_COMMIT="95ae551dd687a0c61227839dda43f52ac7ea6631"   # 2026-08-11
BLESH_PREFIX="$HOME/.local"

# --- Packages ---------------------------------------------------------------
# Install the whole list at once, falling back to one at a time so a package
# this distro happens not to carry does not sink the entire run.
try_install() {
  if ! "$@" "${PKGS[@]}" >/dev/null 2>&1; then
    local pkg
    for pkg in "${PKGS[@]}"; do
      "$@" "$pkg" >/dev/null 2>&1 || warn "Skipped $pkg (not available here)"
    done
  fi
}

install_packages() {
  if is_macos && ! have brew; then
    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi

  if have brew; then
    info "Installing packages with Homebrew"
    PKGS=("${BREW_PKGS[@]}"); try_install brew install
  elif have apt-get; then
    info "Installing packages with apt"
    as_root apt-get update >/dev/null
    PKGS=("${APT_PKGS[@]}"); try_install as_root apt-get install -y
  elif have dnf; then
    info "Installing packages with dnf"
    PKGS=("${DNF_PKGS[@]}"); try_install as_root dnf install -y
  elif have pacman; then
    info "Installing packages with pacman"
    PKGS=("${PACMAN_PKGS[@]}"); try_install as_root pacman -S --needed --noconfirm
  else
    warn "No supported package manager found; install these yourself: ${BREW_PKGS[*]}"
  fi
}

# The macOS layer: GUI tools and the brush/bash shell stack, none of which
# exist on Linux. See ./Brewfile for what is in it and why.
install_macos_extras() {
  is_macos || return 0
  have brew || { warn "Homebrew missing; skipping ./Brewfile"; return 0; }
  info "Installing macOS extras from ./Brewfile"
  # --no-upgrade so it never upgrades things behind your back.
  brew bundle install --file="$DOTFILES/Brewfile" --no-upgrade || \
    warn "Some Brewfile entries failed; run 'brew bundle check --file=$DOTFILES/Brewfile --verbose'"
}

# Starship, uv and ruff are not in most distro repos. Install them from
# upstream into ~/.local so nothing here needs root.
install_missing_tools() {
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"

  if ! have starship; then
    info "Installing starship"
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
  fi

  if ! have uv; then
    info "Installing uv"
    curl -fsSL https://astral.sh/uv/install.sh | sh
  fi

  if ! have ruff && have uv; then
    info "Installing ruff"
    uv tool install ruff
  fi

  have delta || warn "delta is not packaged here — git will fall back to less"
  have lazygit || warn "lazygit is not packaged here — see https://github.com/jesseduffield/lazygit"
  have atuin || warn "atuin is not packaged here — see https://atuin.sh (the bashrc hook is a no-op without it)"
}

# The neovim config needs 0.11+. Debian and Ubuntu ship older builds, so pull
# the current release straight from upstream when that happens.
neovim_is_current() {
  have nvim || return 1
  local version major minor
  version="$(nvim --version | sed -n '1s/^NVIM v\([0-9.]*\).*/\1/p')"
  [ -n "$version" ] || return 1
  major="${version%%.*}"
  minor="${version#*.}"; minor="${minor%%.*}"
  [ "$major" -gt 0 ] || [ "$minor" -ge 11 ]
}

ensure_current_neovim() {
  if neovim_is_current; then return 0; fi

  if is_macos; then
    warn "Neovim is older than 0.11; run: brew upgrade neovim"
    return 0
  fi

  local arch
  case "$(uname -m)" in
    x86_64) arch=x86_64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) warn "No neovim build for $(uname -m); the config needs 0.11+"; return 0 ;;
  esac

  info "Packaged neovim is too old; installing the current release to ~/.local/nvim"
  mkdir -p "$HOME/.local/nvim" "$HOME/.local/bin"
  curl -fsSL "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-$arch.tar.gz" \
    | tar -xz -C "$HOME/.local/nvim" --strip-components=1
  ln -sfn "$HOME/.local/nvim/bin/nvim" "$HOME/.local/bin/nvim"
}

# ble.sh — the fish-like interactive layer for bash. On macOS brush is the
# interactive shell and brings its own highlighting and autosuggestions, so
# ble.sh only improves the bash fallback — still worth having, since bash is
# what ssh, cron and rescue shells land in. Needs bash 4.0+, so on macOS this
# is Homebrew's bash, never /bin/bash (3.2, frozen in 2007 over GPL3).
install_blesh() {
  local target="$BLESH_PREFIX/share/blesh/ble.sh"
  local src="$DOTFILES/.cache/ble.sh"

  if $SKIP_BLESH; then
    info "Skipping ble.sh (--no-blesh); bash will use readline + ~/.inputrc"
    return 0
  fi

  if [ -r "$target" ]; then
    info "ble.sh already installed ($target)"
    return 0
  fi

  # gawk is a real build dependency, not an optional nicety: ble.sh's GNUmakefile
  # hard-fails with "Sorry, gawk could not be found" because it relies on GNU awk
  # extensions that BSD awk (all macOS ships) does not implement.
  for dep in git make gawk; do
    have "$dep" || { warn "$dep is needed to build ble.sh; skipping"; return 0; }
  done

  info "Installing ble.sh at pinned commit ${BLESH_COMMIT:0:12}"

  # A shallow clone cannot check out an arbitrary SHA, so fetch that one object.
  mkdir -p "$(dirname "$src")"
  if [ ! -d "$src/.git" ]; then
    git clone --filter=blob:none --no-checkout \
      https://github.com/akinomyoga/ble.sh.git "$src"
  fi
  git -C "$src" fetch --depth 1 origin "$BLESH_COMMIT"
  git -C "$src" checkout --detach "$BLESH_COMMIT"
  git -C "$src" submodule update --init --recursive --depth 1

  make -C "$src" install PREFIX="$BLESH_PREFIX" || { warn "ble.sh build failed"; return 0; }

  [ -r "$target" ] || warn "ble.sh install did not produce $target"
}

# --- zsh --------------------------------------------------------------------
clone_once() {
  local repo="$1" dest="$2"
  if [ ! -d "$dest" ]; then
    info "Installing $(basename "$dest")"
    git clone --depth 1 "https://github.com/$repo.git" "$dest"
  fi
}

# zsh is still the login shell on Linux, and configs/zshrc is maintained for it.
# On macOS the shell is bash + brush, so the plugins are not needed there.
install_zsh_plugins() {
  is_macos && return 0
  local dir="$HOME/.local/share/zsh/plugins"
  clone_once Aloxaf/fzf-tab "$dir/fzf-tab"
  clone_once zsh-users/zsh-autosuggestions "$dir/zsh-autosuggestions"
  clone_once zsh-users/zsh-syntax-highlighting "$dir/zsh-syntax-highlighting"
}

# --- Secrets ----------------------------------------------------------------
# Config is tracked; credentials never are. The tracked config REFERENCES a
# credential by variable name and something untracked supplies the value.
#
# This is the hard gate: refuse to link (and therefore to make it easy to
# commit) if something credential-shaped is sitting in a tracked file.
refuse_on_tracked_secret() {
  if grep -rqnE '(TOKEN|SECRET|API_KEY|PASSWORD)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_/+-]{20,}' \
       "$DOTFILES/configs" 2>/dev/null; then
    warn "A hardcoded credential appears to be present in configs/."
    warn "Move the value into ~/.config/bash/secrets.sh (mode 600) first."
    warn "Refusing to link."
    exit 1
  fi
}

# ~/.config/bash/secrets.sh holds credential values, is mode 600, and is
# sourced by configs/bashrc if present. ~/.config/bash/local.sh holds
# non-secret machine/work-specific settings (aliases, PATH additions).
scaffold_local_files() {
  local dir="$HOME/.config/bash"
  mkdir -p "$dir"

  if [ ! -f "$dir/secrets.sh" ]; then
    info "Creating $dir/secrets.sh — fill it in"
    cat > "$dir/secrets.sh" <<'EOF'
# ~/.config/bash/secrets.sh — NOT tracked in git. Mode 600.
# Credential values live here and nowhere else. Everything that needs one reads
# it from the environment.
#
# export SOME_API_TOKEN="..."
EOF
  fi
  chmod 600 "$dir/secrets.sh"

  if [ ! -f "$dir/local.sh" ]; then
    info "Creating $dir/local.sh for machine-specific settings"
    cat > "$dir/local.sh" <<'EOF'
# ~/.config/bash/local.sh — NOT tracked in git.
# Non-secret but machine- or employer-specific: work aliases, PATH additions,
# default profiles. Sourced ABOVE the interactive guard in .bashrc, so anything
# added to PATH here also reaches non-interactive shells (launchd, git hooks,
# Hammerspoon's hs.execute()).
#
# path_prepend "$HOME/some/tool/bin"
# export AWS_DEFAULT_PROFILE=...
#
# CAUTION: vendor "path include" snippets written for zsh may use zsh-only
# expansions such as ${(%):-%N}, which raise "bad substitution" in bash and
# then cd into a null directory. Prefer path_prepend over sourcing them.
EOF
  fi

  # espanso: name, email and employer-specific snippets stay out of the repo.
  local esp="$HOME/.config/espanso/match/local.yml"
  if [ ! -f "$esp" ]; then
    mkdir -p "$(dirname "$esp")"
    cat > "$esp" <<'EOF'
# ~/.config/espanso/match/local.yml — NOT tracked in git.
matches: []
#  - trigger: ":me"
#    replace: "Your Name"
#  - trigger: ":@@"
#    replace: "you@example.com"
EOF
  fi

  # doctor.sh greps tracked files for work-internal identifiers. The patterns
  # are themselves employer-specific, so they live here rather than in the repo
  # — a hostname written into the check would be the very leak it prevents.
  local deny="$HOME/.config/dotfiles/denylist"
  if [ ! -f "$deny" ]; then
    mkdir -p "$(dirname "$deny")"
    cat > "$deny" <<'EOF'
# ~/.config/dotfiles/denylist — NOT tracked in git.
# One extended-regex (grep -E) pattern per line. doctor.sh fails if any of them
# appears in a tracked file, because this repo is public. Add your employer's
# name, internal domains, and any account or profile identifiers.
#
# example-corp
# internal\.example\.(net|com)
EOF
  fi

  # Hammerspoon: work hostnames and SSIDs stay out of the repo.
  if is_macos; then
    local hslocal="$HOME/.hammerspoon/local.lua"
    if [ ! -f "$hslocal" ]; then
      mkdir -p "$(dirname "$hslocal")"
      cat > "$hslocal" <<'EOF'
-- ~/.hammerspoon/local.lua — NOT tracked in git.
-- Work hostnames (urldispatch.lua) and SSIDs (wifi.lua) live here.
return {
  work_profile = "Default",
  work_hosts = {},     -- Lua patterns, e.g. "gitlab%.example%.com"
  trusted_ssids = {},  -- e.g. ["Home-5G"] = true
  corp_ssids = {},
}
EOF
    fi
  fi
}

# A commit containing a credential cannot be cleaned up with a normal commit,
# so block it at the source.
install_gitleaks_hook() {
  have gitleaks || { warn "gitleaks not installed — no pre-commit secret scan"; return 0; }
  [ -d "$DOTFILES/.git" ] || return 0
  info "Installing gitleaks pre-commit hook"
  mkdir -p "$DOTFILES/.git/hooks"
  cat > "$DOTFILES/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
# Block commits containing credentials.
if ! gitleaks protect --staged --no-banner --redact; then
  echo ""
  echo "gitleaks found a secret in the staged changes. Commit blocked."
  echo "Move the value into ~/.config/bash/secrets.sh. Do not use --no-verify."
  exit 1
fi
EOF
  chmod +x "$DOTFILES/.git/hooks/pre-commit"
}

# --- Symlinks ---------------------------------------------------------------
# ~/.gitconfig is about to be replaced, so keep the identity it carries.
save_git_identity() {
  local target="$HOME/.gitconfig.local" name email
  [ -f "$target" ] && return 0
  name="$(git config --global --get user.name 2>/dev/null || true)"
  email="$(git config --global --get user.email 2>/dev/null || true)"
  if [ -n "$name" ] || [ -n "$email" ]; then
    info "Copying your git identity into ~/.gitconfig.local"
    printf '[user]\n' > "$target"
    [ -n "$name" ] && printf '\tname = %s\n' "$name" >> "$target"
    [ -n "$email" ] && printf '\temail = %s\n' "$email" >> "$target"
  fi
  return 0
}

link() {
  local src="$DOTFILES/$1" dest="$HOME/$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.backup"
    info "Backed up existing $dest to $dest.backup"
  fi
  ln -sfn "$src" "$dest"
  info "Linked ~/$2"
}

link_configs() {
  # Portable: linked on macOS and Linux alike.
  link configs/zshrc            .zshrc
  link configs/bashrc           .bashrc
  link configs/bash_profile     .bash_profile
  link configs/inputrc          .inputrc
  link configs/starship.toml    .config/starship.toml
  link configs/tmux.conf        .tmux.conf
  link configs/nvim-init.lua    .config/nvim/init.lua
  link configs/gitconfig        .gitconfig
  link configs/gitignore_global .gitignore_global
  link configs/editorconfig     .editorconfig
  link configs/words            .words
  link configs/atuin.toml       .config/atuin/config.toml
  link configs/espanso/config/default.yml .config/espanso/config/default.yml
  link configs/espanso/match/base.yml     .config/espanso/match/base.yml
  link configs/espanso/match/netops.yml   .config/espanso/match/netops.yml
}

# macOS-only. AeroSpace, Hammerspoon, Karabiner, Ghostty and Leader Key do not
# exist on Linux, and brush is only the interactive shell on macOS — linking any
# of these there would leave dead config behind.
link_macos_configs() {
  is_macos || return 0

  link configs/brushrc        .brushrc
  link configs/aerospace.toml .aerospace.toml
  link configs/ghostty        .config/ghostty/config
  link configs/karabiner.edn  .config/karabiner.edn

  link configs/hammerspoon/init.lua                  .hammerspoon/init.lua
  link configs/hammerspoon/modules/camera.lua        .hammerspoon/modules/camera.lua
  link configs/hammerspoon/modules/power.lua         .hammerspoon/modules/power.lua
  link configs/hammerspoon/modules/urldispatch.lua   .hammerspoon/modules/urldispatch.lua
  link configs/hammerspoon/modules/usbconsole.lua    .hammerspoon/modules/usbconsole.lua
  link configs/hammerspoon/modules/wifi.lua          .hammerspoon/modules/wifi.lua

  # Leader Key lives outside XDG and its config.json embeds absolute paths to
  # your own applications, so it is untracked. Link it only if you have made a
  # local copy at configs/leaderkey.json (gitignored).
  if [ -f "$DOTFILES/configs/leaderkey.json" ]; then
    local lk="$HOME/Library/Application Support/Leader Key"
    mkdir -p "$lk"
    if [ -e "$lk/config.json" ] && [ ! -L "$lk/config.json" ]; then
      mv "$lk/config.json" "$lk/config.json.backup"
      info "Backed up existing Leader Key config.json"
    fi
    ln -sfn "$DOTFILES/configs/leaderkey.json" "$lk/config.json"
    info "Linked Leader Key config.json"
  fi
}

# Things a symlink cannot express, all macOS-only.
macos_special_cases() {
  is_macos || return 0

  # espanso defaults to ~/Library/Application Support/espanso on macOS. Move it
  # aside so ~/.config/espanso wins. espanso must be stopped while that happens.
  if have espanso; then
    local esp_default="$HOME/Library/Application Support/espanso"
    if [ -d "$esp_default" ] && [ ! -L "$esp_default" ]; then
      info "Moving espanso's Application Support config aside so ~/.config/espanso wins"
      espanso stop >/dev/null 2>&1 || true
      mv "$esp_default" "$esp_default.backup"
    fi
    espanso service register >/dev/null 2>&1 || true
    espanso start >/dev/null 2>&1 || true
  fi

  # Karabiner: karabiner.json is GENERATED, never linked. Karabiner replaces a
  # symlinked JSON with a real file, so goku compiles into place instead.
  if have goku; then
    # goku UPDATES an existing karabiner.json rather than creating one from
    # scratch, and dies with a Java FileNotFoundException if it is absent.
    # Karabiner-Elements writes that file the first time it launches, so the
    # cask has to be installed and opened once before goku can do anything.
    if [ -f "$HOME/.config/karabiner/karabiner.json" ]; then
      info "Compiling karabiner.edn -> karabiner.json via goku"
      goku >/dev/null 2>&1 || warn "goku failed — run 'goku' by hand to see why"
      brew services start goku >/dev/null 2>&1 || true   # gokuw: recompile on save
    else
      warn "~/.config/karabiner/karabiner.json does not exist yet, so goku cannot run."
      warn "  Install Karabiner-Elements and launch it once, then run: goku"
    fi
  else
    warn "goku not installed; karabiner.edn will not be compiled"
  fi

  if have aerospace; then
    aerospace reload-config >/dev/null 2>&1 || true
  fi

  # init.lua installs an hs.pathwatcher on ~/.hammerspoon/, so linking already
  # triggered a reload. Start Hammerspoon if it was not running.
  if ! pgrep -qx Hammerspoon && [ -d /Applications/Hammerspoon.app ]; then
    open -g -a Hammerspoon >/dev/null 2>&1 || true
  fi
}

# --- Default shell ----------------------------------------------------------
# macOS: Homebrew bash. NOT brush — brush needs --enable-zsh-hooks (required
# for atuin) and --enable-highlighting, and chsh cannot pass arguments, so
# brush is launched by Ghostty's `command =` line instead. bash also stays the
# right choice for ssh, cron, launchd, git hooks and hs.execute(), where a v0.4
# reimplementation is not what you want.
# Linux: zsh, with configs/zshrc.
set_default_shell() {
  local target
  if is_macos; then
    # Homebrew's bash, not /bin/bash (3.2). The prefix differs on Apple Silicon
    # and Intel, so ask brew rather than hardcoding it.
    target="$(brew --prefix 2>/dev/null || echo /opt/homebrew)/bin/bash"
    [ -x "$target" ] || { warn "$target missing — run without --no-packages first"; return 0; }
  else
    target="$(command -v zsh || true)"
    [ -n "$target" ] || return 0
  fi

  local current="${SHELL:-}"
  if is_macos; then
    current="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
  fi
  [ "$current" = "$target" ] && { info "Login shell is already $target"; return 0; }

  # /etc/shells is a system file and chsh refuses any shell absent from it.
  if ! grep -qxF "$target" /etc/shells 2>/dev/null; then
    if is_macos; then
      # Deliberately not done silently on macOS: both commands need your
      # password, and editing a system file behind your back is not on.
      warn "$target is not in /etc/shells, so chsh will refuse. Run these yourself:"
      echo
      echo "    echo '$target' | sudo tee -a /etc/shells"
      echo "    chsh -s '$target'"
      echo
      warn "Everything else is in place — try it here first: exec $target --login"
      return 0
    fi
    as_root sh -c "echo '$target' >> /etc/shells"
  fi

  info "Setting $target as the default shell"
  chsh -s "$target" || warn "Could not change the shell; run it yourself: chsh -s $target"
}

main() {
  if ! $SKIP_PACKAGES; then
    install_packages
    install_macos_extras
    install_missing_tools
    ensure_current_neovim
    install_blesh
  fi
  install_zsh_plugins
  refuse_on_tracked_secret
  scaffold_local_files
  install_gitleaks_hook
  save_git_identity
  link_configs
  link_macos_configs
  macos_special_cases
  set_default_shell

  info "Done. Open a new terminal; neovim installs its plugins on first launch."
  echo
  echo "  Verify with: ./doctor.sh"
  if is_macos; then
    echo
    echo "  Two shells, one ~/.bashrc:"
    echo "    brush  interactive, launched by Ghostty with its two required flags"
    echo "    bash   login/system: ssh, cron, launchd, git hooks, hs.execute()"
    echo
    echo "  In a NEW Ghostty window, confirm atuin still records — this is the"
    echo "  one brush failure mode that is otherwise completely silent:"
    echo "    echo canary-\$RANDOM && atuin search canary"
    echo
    echo "  Manual steps macOS will not let a script do:"
    echo "    1. Add bash to /etc/shells and change your login shell (needs sudo)"
    echo "    2. Grant Accessibility + Input Monitoring to Hammerspoon, AeroSpace,"
    echo "       Karabiner-Elements, espanso -> System Settings > Privacy & Security"
    echo "    3. Karabiner: approve the driver extension when prompted"
    echo "    4. Set Hammerspoon as the default browser IF you want urldispatch.lua"
    echo "    5. Fill in ~/.config/bash/secrets.sh and ~/.config/bash/local.sh,"
    echo "       plus ~/.hammerspoon/local.lua and ~/.config/espanso/match/local.yml"
  fi
}

main
