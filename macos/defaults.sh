#!/usr/bin/env bash
#
# macos/defaults.sh — the escape hatch for tools with no text config.
#
# Raycast, Homerow, CleanShot, BetterTouchTool and Ice all store settings in
# macOS preference domains, not files you can sensibly hand-edit. You cannot
# stow them. But you CAN snapshot and restore them, which gets you most of the
# way to reproducibility.
#
#   ./defaults.sh export     snapshot GUI app prefs into ./exported/  (COMMIT THESE)
#   ./defaults.sh import     restore those snapshots onto this machine
#   ./defaults.sh system     apply the curated macOS system settings below
#
# Workflow: configure an app through its UI until you like it, run `export`,
# commit the diff. That gives you a versioned record and a restore path.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/exported"

# Preference domains worth tracking. Verify a domain exists before trusting it:
#   defaults domains | tr ',' '\n' | grep -i raycast
# Every name below was verified against the full `defaults domains` enumeration
# on this machine — not guessed. Two of the obvious guesses were wrong:
# CleanShot is pl.maketheweb.cleanshotx (not pl.maq.CleanShot) and Leader Key is
# com.brnbw.Leader-Key.
DOMAINS=(
  com.raycast.macos                # Raycast
  com.superultra.Homerow           # Homerow
  pl.maketheweb.cleanshotx         # CleanShot X
  com.hegenberg.BetterTouchTool    # BetterTouchTool
  com.brnbw.Leader-Key             # Leader Key (app prefs; config.json is stowed)
  com.lwouis.alt-tab-macos         # AltTab
  md.obsidian                      # Obsidian
  net.shinyfrog.bear               # Bear (workspace 4 in .aerospace.toml)
  org.hammerspoon.Hammerspoon      # Hammerspoon app prefs (init.lua is stowed)
  com.mitchellh.ghostty            # Ghostty app prefs (config file is stowed)

  # Not installed yet — will be skipped harmlessly until it is:
  com.jordanbaird.Ice              # Ice menu bar manager
)

# DELIBERATELY NOT EXPORTED:
#   com.lwouis.alt-tab-macos.license   licence material, not settings
# Anything ending in .license or holding activation data stays out of git.

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!!\033[0m %s\n' "$*"; }

cmd_export() {
  mkdir -p "$OUT"
  say "Exporting preference domains -> $OUT"
  for d in "${DOMAINS[@]}"; do
    # `defaults read <domain>` is a fast existence probe. Do NOT use
    # `defaults domains` here: it enumerates every domain on the system and
    # takes well over a minute on a machine with a lot of apps installed.
    if defaults read "$d" >/dev/null 2>&1; then
      defaults export "$d" "$OUT/$d.plist"
      # Convert to XML so git produces a readable diff, not a binary blob.
      plutil -convert xml1 "$OUT/$d.plist"
      say "  exported $d"
    else
      warn "  domain not present, skipping: $d"
    fi
  done
  echo
  say "Review and commit: git add macos/exported && git diff --cached"
}

cmd_import() {
  [[ -d "$OUT" ]] || { warn "no exported/ directory — run 'export' first"; exit 1; }
  warn "This overwrites live app preferences. Quit the apps first."
  read -r -p "Continue? [y/N] " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]] || exit 0

  for f in "$OUT"/*.plist; do
    [[ -e "$f" ]] || continue
    d="$(basename "$f" .plist)"
    say "  importing $d"
    defaults import "$d" "$f"
  done
  warn "Log out and back in for everything to take effect."
}

cmd_system() {
  say "Applying curated macOS system settings"

  # --- Keyboard -------------------------------------------------------------
  # Fast key repeat. The single biggest quality-of-life change for anyone who
  # navigates with hjkl. Values below the System Settings slider minimum.
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15

  # Disable press-and-hold accent menu so key repeat actually works in every app.
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

  # Full keyboard access: Tab moves between all controls, not just text fields.
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

  # --- Text input -----------------------------------------------------------
  # Turn off "helpful" substitutions that corrupt code, configs and CLI output.
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

  # --- Window & animation ---------------------------------------------------
  # AeroSpace tiles instantly; macOS animations just add latency on top.
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
  defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

  # Save/print dialogs expanded by default.
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

  # --- Dock -----------------------------------------------------------------
  # With AeroSpace + Leader Key you never click the Dock; reclaim the space.
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 1000   # effectively never
  defaults write com.apple.dock autohide-time-modifier -float 0
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock mru-spaces -bool false       # don't reorder Spaces

  # --- Finder ---------------------------------------------------------------
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search cwd
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  # Stop writing .DS_Store onto network and USB volumes.
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

  # --- Screenshots ----------------------------------------------------------
  # CleanShot X handles capture, but keep the native ones tidy as a fallback.
  mkdir -p "$HOME/Pictures/Screenshots"
  defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
  defaults write com.apple.screencapture type -string "png"
  defaults write com.apple.screencapture disable-shadow -bool true

  # --- Misc -----------------------------------------------------------------
  # Crash reporter dialogs are noise on a dev machine.
  defaults write com.apple.CrashReporter DialogType -string "none"
  # Ask for password immediately after sleep/screensaver.
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

  say "Restarting affected services"
  killall Dock >/dev/null 2>&1 || true
  killall Finder >/dev/null 2>&1 || true
  killall SystemUIServer >/dev/null 2>&1 || true

  warn "Some settings need a logout to take effect."
}

case "${1:-}" in
  export) cmd_export ;;
  import) cmd_import ;;
  system) cmd_system ;;
  *) echo "usage: $0 {export|import|system}" >&2; exit 2 ;;
esac
