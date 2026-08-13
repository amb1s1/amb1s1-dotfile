#!/usr/bin/env bash
# Install these dotfiles on macOS or Linux.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(git zsh tmux neovim curl fzf ripgrep bat)

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# --- Packages ---------------------------------------------------------------
install_packages() {
  if [ "$(uname -s)" = "Darwin" ] && ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi

  if command -v brew >/dev/null 2>&1; then
    info "Installing packages with Homebrew"
    brew install "${PACKAGES[@]}"
  elif command -v apt-get >/dev/null 2>&1; then
    info "Installing packages with apt"
    as_root apt-get update
    as_root apt-get install -y "${PACKAGES[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    info "Installing packages with dnf"
    as_root dnf install -y "${PACKAGES[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    info "Installing packages with pacman"
    as_root pacman -Sy --needed --noconfirm "${PACKAGES[@]}"
  else
    info "No supported package manager found. Install these yourself: ${PACKAGES[*]}"
  fi
}

# --- zsh --------------------------------------------------------------------
clone_once() {
  local repo="$1" dest="$2"
  if [ ! -d "$dest" ]; then
    info "Installing $(basename "$dest")"
    git clone --depth 1 "https://github.com/$repo.git" "$dest"
  fi
}

install_zsh_extras() {
  local custom="$HOME/.oh-my-zsh/custom"
  clone_once ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh"
  clone_once zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions"
  clone_once zsh-users/zsh-syntax-highlighting "$custom/plugins/zsh-syntax-highlighting"
}

# --- Symlinks ---------------------------------------------------------------
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
  link configs/zshrc          .zshrc
  link configs/tmux.conf      .tmux.conf
  link configs/editorconfig   .editorconfig
  link configs/nvim-init.vim  .config/nvim/init.vim
  link configs/words          .words
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
    chsh -s "$zsh_path" || info "Could not change the shell; run it yourself: chsh -s $zsh_path"
  fi
}

main() {
  if [ "${1:-}" != "--no-packages" ]; then
    install_packages
  fi
  install_zsh_extras
  link_configs
  set_default_shell
  info "Done. Open a new terminal; neovim installs its plugins on first launch."
}

main "$@"
