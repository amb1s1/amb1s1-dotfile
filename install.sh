#!/usr/bin/env bash
# Install these dotfiles on macOS or Linux.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# Package names differ per manager, and not every tool is packaged everywhere.
# Whatever is missing afterwards is picked up by install_missing_tools.
BREW_PKGS=(git zsh tmux neovim curl fzf ripgrep bat eza fd git-delta zoxide
           lazygit btop starship uv ruff node stylua shfmt)
APT_PKGS=(git zsh tmux neovim curl fzf ripgrep bat fd-find git-delta zoxide
          btop eza nodejs npm shfmt)
DNF_PKGS=(git zsh tmux neovim curl fzf ripgrep bat fd-find git-delta zoxide
          btop eza nodejs npm lazygit shfmt)
PACMAN_PKGS=(git zsh tmux neovim curl fzf ripgrep bat fd git-delta zoxide
             btop eza nodejs npm lazygit starship uv ruff shfmt)

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
  if [ "$(uname -s)" = "Darwin" ] && ! have brew; then
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

  if [ "$(uname -s)" = "Darwin" ]; then
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

# --- zsh --------------------------------------------------------------------
clone_once() {
  local repo="$1" dest="$2"
  if [ ! -d "$dest" ]; then
    info "Installing $(basename "$dest")"
    git clone --depth 1 "https://github.com/$repo.git" "$dest"
  fi
}

install_zsh_plugins() {
  local dir="$HOME/.local/share/zsh/plugins"
  clone_once Aloxaf/fzf-tab "$dir/fzf-tab"
  clone_once zsh-users/zsh-autosuggestions "$dir/zsh-autosuggestions"
  clone_once zsh-users/zsh-syntax-highlighting "$dir/zsh-syntax-highlighting"
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
  link configs/zshrc            .zshrc
  link configs/starship.toml    .config/starship.toml
  link configs/tmux.conf        .tmux.conf
  link configs/nvim-init.lua    .config/nvim/init.lua
  link configs/gitconfig        .gitconfig
  link configs/gitignore_global .gitignore_global
  link configs/editorconfig     .editorconfig
  link configs/words            .words
}

# --- Default shell ----------------------------------------------------------
set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"

  if [ -n "$zsh_path" ] && [ "${SHELL:-}" != "$zsh_path" ]; then
    info "Setting zsh as the default shell"
    if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
      as_root sh -c "echo '$zsh_path' >> /etc/shells"
    fi
    chsh -s "$zsh_path" || warn "Could not change the shell; run it yourself: chsh -s $zsh_path"
  fi
}

main() {
  if [ "${1:-}" != "--no-packages" ]; then
    install_packages
    install_missing_tools
    ensure_current_neovim
  fi
  install_zsh_plugins
  save_git_identity
  link_configs
  set_default_shell
  info "Done. Open a new terminal; neovim installs its plugins on first launch."
}

main "$@"
