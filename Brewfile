# Brewfile — macOS-only extras.
#
# install.sh installs the cross-platform core (BREW_PKGS/APT_PKGS/…) on every
# platform. This file is the macOS layer on top: the GUI tools and the shell
# stack that only exist here. It is applied by install.sh on macOS, or by hand:
#
#   brew bundle install --file=./Brewfile --no-upgrade   install what is missing
#   brew bundle check   --file=./Brewfile                report drift, change nothing
#
# Deliberately curated, not dumped: every entry below is something a config in
# this repo actually references. Personal apps and language toolchains are not
# listed — install those however you like.

tap "yqrashawn/goku"           # goku (karabiner.edn compiler)

# --- Shells ------------------------------------------------------------------
# TWO SHELLS, ONE CONFIG. Both read ~/.bashrc.
#
#   brush  INTERACTIVE shell, launched by Ghostty with the two flags it needs
#          (--enable-zsh-hooks, --enable-highlighting). Rust bash
#          reimplementation; highlighting + autosuggestions built in.
#          v0.4 — `select` unsupported, traps/options in progress upstream.
#   bash   SYSTEM shell: login, ssh, cron, launchd, git hooks, hs.execute().
#          Homebrew's 5.x, never /bin/bash (3.2, frozen in 2007 over GPL3).
brew "bash"
brew "fish"                  # THE interactive shell; configs/ghostty launches it

# Tested and rejected: oils-for-unix (OSH) is the most bash-compatible
# alternative in principle but unusable on macOS — extended globs need
# FNM_EXTMATCH, a glibc extension absent from BSD libc, so OSH cannot even
# parse atuin's init script here. murex and elvish each have their own
# language, which fails the compatibility test that drove this setup.

# --- Terminal & prompt -------------------------------------------------------
cask "ghostty"               # config: configs/ghostty -> ~/.config/ghostty/config
brew "atuin"                 # history; config: configs/atuin.toml
brew "gitleaks"              # pre-commit secret scanning

# --- Window management / input ----------------------------------------------
cask "hammerspoon"                  # system-event glue; config: configs/hammerspoon/
cask "karabiner-elements"           # key remapping at driver level
brew "yqrashawn/goku/goku"          # compiles karabiner.edn -> karabiner.json
cask "espanso"                      # text expansion; config: configs/espanso/
cask "leader-key"                   # launcher (config.json is untracked)

# --- Fonts -------------------------------------------------------------------
cask "font-jetbrains-mono"   # ghostty's font-family
cask "font-hack-nerd-font"   # Powerline glyphs for tmux/starship

# --- Serial console ----------------------------------------------------------
brew "picocom"               # used by configs/hammerspoon/modules/usbconsole.lua
                             # and the console() function in configs/bashrc
brew "mtr"                   # the mtrr alias

# NOT AVAILABLE VIA HOMEBREW:
#   ble.sh   The bash line editor providing fish-style autosuggestions, syntax
#            highlighting and vim modes. No formula exists. install.sh builds
#            it from a PINNED COMMIT — upstream's newest git tag is from 2023
#            while master is committed to weekly, so a version tag would pin
#            you to genuinely old code. The SHA lives in install.sh.
