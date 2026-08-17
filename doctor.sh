#!/usr/bin/env bash
#
# doctor.sh — verify the setup is actually wired up. Read-only; changes nothing.
#
# Run this after install.sh, and any time something feels off. The failure modes
# it catches are the annoying ones: a config that looks committed but is not
# linked, a symlink Karabiner silently replaced with a real file, a credential
# that crept back into a tracked file, and the shell integration order that
# stops atuin recording history without any error at all.
#
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; WARN=0

ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr()  { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

BASHRC="$DOTFILES/configs/bashrc"
SHIP="$DOTFILES/configs/starship.toml"

# -----------------------------------------------------------------------------
hdr "Symlinks (config in repo == config in use)"

check_link() {
  local target="$HOME/$1" expected="$DOTFILES/$2"
  if [[ ! -e "$target" ]]; then
    bad "missing: ~/$1"
  elif [[ ! -L "$target" ]]; then
    bad "NOT a symlink (real file shadowing the repo): ~/$1"
  elif [[ "$(readlink "$target")" != "$expected" ]]; then
    warn "symlink points elsewhere: ~/$1 -> $(readlink "$target")"
  else
    ok "~/$1"
  fi
}

check_link ".bashrc"                   "configs/bashrc"
check_link ".bash_profile"             "configs/bash_profile"
check_link ".inputrc"                  "configs/inputrc"
check_link ".zshrc"                    "configs/zshrc"
check_link ".config/starship.toml"     "configs/starship.toml"
check_link ".tmux.conf"                "configs/tmux.conf"
check_link ".config/nvim/init.lua"     "configs/nvim-init.lua"
check_link ".gitconfig"                "configs/gitconfig"
check_link ".config/atuin/config.toml" "configs/atuin.toml"

if is_macos; then
  check_link ".brushrc"                "configs/brushrc"
  check_link ".aerospace.toml"         "configs/aerospace.toml"
  check_link ".config/ghostty/config"  "configs/ghostty"
  check_link ".config/karabiner.edn"   "configs/karabiner.edn"
  check_link ".hammerspoon/init.lua"   "configs/hammerspoon/init.lua"
fi

# -----------------------------------------------------------------------------
hdr "Machine-specific files (untracked by design)"

# Identity is NEVER committed: configs/gitconfig includes ~/.gitconfig.local.
if [[ -f "$HOME/.gitconfig.local" ]]; then
  ok "~/.gitconfig.local present (git identity stays out of the repo)"
else
  warn "no ~/.gitconfig.local — git has no user.name/user.email"
fi

if [[ -f "$HOME/.config/bash/local.sh" ]]; then
  ok "~/.config/bash/local.sh present"
else
  warn "no ~/.config/bash/local.sh — work aliases and PATH additions have no home"
fi

if is_macos; then
  if [[ -f "$HOME/.hammerspoon/local.lua" ]]; then
    ok "~/.hammerspoon/local.lua present (work hosts + SSIDs stay local)"
  else
    warn "no ~/.hammerspoon/local.lua — urldispatch and wifi fall back to defaults"
  fi
fi

# -----------------------------------------------------------------------------
hdr "Generated artefacts (must NOT be symlinks)"

if is_macos; then
  kj="$HOME/.config/karabiner/karabiner.json"
  if [[ -L "$kj" ]]; then
    bad "karabiner.json is a symlink — Karabiner will replace it. Let goku generate it."
  elif [[ -f "$kj" ]]; then
    if [[ "$DOTFILES/configs/karabiner.edn" -nt "$kj" ]]; then
      warn "karabiner.edn is newer than karabiner.json — run: goku"
    else
      ok "karabiner.json generated and current"
    fi
  else
    warn "karabiner.json absent — run: goku"
  fi
fi

# -----------------------------------------------------------------------------
hdr "Secrets"

if [[ -f "$HOME/.config/bash/secrets.sh" ]]; then
  if is_macos; then perms="$(stat -f '%Lp' "$HOME/.config/bash/secrets.sh")"
  else perms="$(stat -c '%a' "$HOME/.config/bash/secrets.sh")"; fi
  [[ "$perms" == "600" ]] && ok "secrets.sh present, mode 600" \
                          || bad "secrets.sh is mode $perms — should be 600"
else
  warn "no ~/.config/bash/secrets.sh (fine if you use 1Password CLI instead)"
fi

# .bashrc must actually source it, or the whole convention is decorative.
if grep -q 'bash/secrets.sh' "$BASHRC" 2>/dev/null; then
  ok ".bashrc sources ~/.config/bash/secrets.sh"
else
  bad ".bashrc does not source ~/.config/bash/secrets.sh"
fi

# Nothing credential-shaped in tracked files.
if grep -rqnE '(TOKEN|SECRET|API_KEY|PASSWORD)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_/+-]{20,}' \
     "$DOTFILES/configs" 2>/dev/null; then
  bad "a hardcoded credential appears in a TRACKED file"
else
  ok "no hardcoded credentials in tracked configs"
fi

# This repo is PUBLIC. Internal hostnames and work identifiers must stay in the
# untracked local files, not in configs/.
#
# The patterns themselves are employer-specific, so they are NOT hardcoded here
# — an internal hostname written into this check would be exactly the leak the
# check exists to prevent. One extended-regex pattern per line in:
DENYLIST="$HOME/.config/dotfiles/denylist"
if [[ ! -d "$DOTFILES/.git" ]]; then
  :
elif [[ ! -r "$DENYLIST" ]]; then
  warn "no $DENYLIST — cannot check tracked files for internal identifiers"
else
  hits=0
  while IFS= read -r pat; do
    [[ -z "$pat" || "$pat" == \#* ]] && continue
    if git -C "$DOTFILES" grep -qiE -- "$pat" 2>/dev/null; then
      bad "denylisted pattern '$pat' appears in a TRACKED file — this repo is public"
      hits=$((hits+1))
    fi
  done < "$DENYLIST"
  (( hits == 0 )) && ok "no denylisted identifiers in tracked files"
fi

# Personal application state must not be tracked either.
if [[ -d "$DOTFILES/.git" ]] && git -C "$DOTFILES" ls-files --error-unmatch \
     macos/exported >/dev/null 2>&1; then
  bad "macos/exported/ is tracked — personal app prefs would be published"
else
  ok "macos/exported/ is not tracked"
fi

if [[ -x "$DOTFILES/.git/hooks/pre-commit" ]]; then
  ok "gitleaks pre-commit hook installed"
else
  warn "no pre-commit hook — a secret could be committed by accident"
fi

# -----------------------------------------------------------------------------
hdr "Tools on PATH"

for t in git starship atuin fzf rg bat eza fd zoxide delta; do
  command -v "$t" >/dev/null 2>&1 && ok "$t" || warn "$t not on PATH"
done

if is_macos; then
  for t in brew brush carapace aerospace goku espanso borders; do
    command -v "$t" >/dev/null 2>&1 && ok "$t" || warn "$t not on PATH"
  done
  [[ -d /Applications/Hammerspoon.app ]] && ok "Hammerspoon.app" \
                                         || warn "Hammerspoon.app missing"
fi

# -----------------------------------------------------------------------------
hdr "Shell"

# --- .bashrc invariants (these hold on every platform) -----------------------
if [[ -r "$BASHRC" ]]; then
  # PATH must be set ABOVE the interactive guard, or non-interactive shells
  # (Hammerspoon's hs.execute, launchd, cron, git hooks) get a broken PATH.
  guard_line="$(grep -n 'case \$- in \*i\*' "$BASHRC" | head -1 | cut -d: -f1)"
  # The LAST line that touches PATH, not the first: everything must be above
  # the guard, so anchoring on the first one would miss a later addition.
  path_line="$(grep -nE 'shellenv|^export PATH' "$BASHRC" | tail -1 | cut -d: -f1)"
  if [[ -n "$guard_line" && -n "$path_line" ]] && (( path_line < guard_line )); then
    ok "PATH is set above the interactive guard"
  else
    bad "PATH is set BELOW the interactive guard — non-interactive shells will break"
  fi

  # The ble.sh / starship / atuin load order is load-bearing; see configs/bashrc.
  # Assert it here so a future edit cannot silently break history recording.
  ble_src="$(grep -n 'blesh/ble.sh' "$BASHRC" | head -1 | cut -d: -f1)"
  ship_line="$(grep -n 'starship init bash' "$BASHRC" | head -1 | cut -d: -f1)"
  atuin_line="$(grep -n 'atuin init bash' "$BASHRC" | head -1 | cut -d: -f1)"
  attach_line="$(grep -n 'ble-attach' "$BASHRC" | tail -1 | cut -d: -f1)"
  if [[ -n "$ble_src" && -n "$ship_line" && -n "$atuin_line" && -n "$attach_line" ]] \
     && (( ble_src < ship_line && ship_line < atuin_line && atuin_line < attach_line )); then
    ok "ble.sh -> starship -> atuin -> ble-attach order is correct"
  else
    bad "shell integration order is wrong — atuin history recording will break"
  fi

  # ble.sh must be guarded so it never loads inside brush. BASH_VERSION is NOT
  # a valid discriminator: brush reports 5.2.37 on purpose, so a BASH_VERSION
  # test matches brush and loads ble.sh into the wrong shell.
  #
  # Inspect the guard on the `source ble.sh` line itself, not the file as a
  # whole — a passing mention of BRUSH_VERSION in a comment proves nothing.
  ble_guard="$(grep -n 'blesh/ble.sh' "$BASHRC" | head -1 | cut -d: -f1)"
  if [[ -z "$ble_guard" ]]; then
    bad "no ble.sh source line in .bashrc"
  else
    guard_txt="$(sed -n "${ble_guard}p" "$BASHRC")"
    if [[ "$guard_txt" == *BASH_VERSION* ]]; then
      bad "the ble.sh guard tests BASH_VERSION — brush reports 5.2.37, so ble.sh will load into it"
    elif [[ "$guard_txt" == *BRUSH_VERSION* ]]; then
      ok "ble.sh source line is BRUSH_VERSION-guarded"
    else
      bad "the ble.sh source line has no BRUSH_VERSION guard — it will load into brush"
    fi
  fi

  # The brush flag check must inspect our own invocation via ps. Testing
  # preexec_functions instead silently always passes: atuin populates that
  # array whether or not --enable-zsh-hooks is present; brush just never
  # invokes it.
  if grep -q 'ps -o command= -p \$\$' "$BASHRC"; then
    ok "brush flag check uses ps, not preexec_functions"
  else
    bad "brush flag check does not use 'ps -o command= -p \$\$' — it will always pass"
  fi
fi

if [[ -r "$DOTFILES/configs/bash_profile" ]]; then
  grep -q 'source ~/.bashrc' "$DOTFILES/configs/bash_profile" \
    && ok ".bash_profile sources .bashrc (macOS opens login shells)" \
    || bad ".bash_profile does not source .bashrc — nothing will load on macOS"
fi

BASH_BIN="$(command -v bash)"
if is_macos; then
  BREW_BASH="$(brew --prefix 2>/dev/null || echo /opt/homebrew)/bin/bash"
  if [[ -x "$BREW_BASH" ]]; then
    BASH_BIN="$BREW_BASH"
    bver="$("$BREW_BASH" -c 'echo ${BASH_VERSINFO[0]}')"
    (( bver >= 4 )) && ok "Homebrew bash $("$BREW_BASH" -c 'echo $BASH_VERSION')" \
                    || bad "Homebrew bash is v$bver — ble.sh needs 4.0+"
  else
    bad "no $BREW_BASH — system /bin/bash 3.2 is too old for ble.sh"
  fi
fi

if [[ -r "$HOME/.local/share/blesh/ble.sh" ]]; then
  ok "ble.sh installed (bash line editor)"
else
  warn "ble.sh missing — bash has no autosuggestions (brush unaffected)"
fi

# --- brush: the interactive shell on macOS ----------------------------------
if is_macos; then
  if command -v brush >/dev/null 2>&1; then
    ok "brush $(brush --version 2>/dev/null | awk '{print $2}')"

    # The two flags MUST be on Ghostty's command line — chsh cannot pass
    # arguments, which is the whole reason brush is launched from Ghostty.
    # --enable-zsh-hooks is the dangerous one: without it brush registers
    # atuin's preexec_functions but never invokes them, so history recording
    # fails with no error at all.
    gcfg="$DOTFILES/configs/ghostty"
    if [[ -r "$gcfg" ]]; then
      cmdline="$(grep -E '^\s*command\s*=' "$gcfg" | head -1)"
      if [[ "$cmdline" == *brush* ]]; then
        [[ "$cmdline" == *--enable-zsh-hooks* ]] \
          && ok "Ghostty passes --enable-zsh-hooks (atuin will record)" \
          || bad "Ghostty launches brush WITHOUT --enable-zsh-hooks — atuin will silently stop recording"
        [[ "$cmdline" == *--enable-highlighting* ]] \
          && ok "Ghostty passes --enable-highlighting" \
          || warn "no --enable-highlighting — brush will run unhighlighted"
      else
        warn "Ghostty is not launching brush (currently: ${cmdline:-unset})"
      fi
    fi

    # brush must be able to read the shared .bashrc.
    brush -n "$BASHRC" >/dev/null 2>&1 \
      && ok "brush parses the shared .bashrc" \
      || bad "brush cannot parse .bashrc"

    # brush's config.toml schema is undocumented and unknown keys are silently
    # accepted, so a plausible-looking config is an invisible no-op. .brushrc
    # (documented) is used instead.
    [[ -e "$HOME/.config/brush/config.toml" ]] \
      && bad "~/.config/brush/config.toml exists — undocumented schema, silently ignores unknown keys" \
      || ok "no ~/.config/brush/config.toml (deliberate)"
  else
    warn "brush not installed — the Ghostty config expects it"
  fi

  # brush must never be the login shell: chsh cannot pass its required flags.
  login_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
  case "$login_shell" in
    *brush*) bad "login shell is brush — chsh cannot pass --enable-zsh-hooks; use bash" ;;
    "$BASH_BIN") ok "login shell is $BASH_BIN" ;;
    *) warn "login shell is $login_shell (not yet switched — see install.sh output)" ;;
  esac

  grep -qxF "$BASH_BIN" /etc/shells 2>/dev/null && ok "$BASH_BIN is in /etc/shells" \
    || warn "$BASH_BIN not in /etc/shells — chsh will refuse until added (sudo)"

  # OSH cannot work on macOS (no FNM_EXTMATCH in BSD libc); flag it if lingering.
  command -v osh >/dev/null 2>&1 && \
    warn "oils-for-unix still installed — unusable on macOS; brew uninstall oils-for-unix"

  # fish is the documented rollback path. Do not remove it.
  command -v fish >/dev/null 2>&1 && ok "fish still installed (rollback path)" \
    || warn "fish is gone — the documented rollback path no longer exists"
fi

# Does atuin actually record? The order above is necessary but not sufficient,
# and a silent failure here means you lose history without noticing.
#
# Query the SQLite database directly rather than going through the atuin CLI.
# Every atuin read subcommand (`history list`, `search`, `stats`) refuses to run
# without $ATUIN_SESSION in the environment, which only an initialised
# interactive shell sets — so from a script they all fail even when recording is
# working perfectly. `history list --limit` does not exist at all as of 18.19.
if command -v atuin >/dev/null 2>&1; then
  atuin_db="${ATUIN_DB:-$HOME/.local/share/atuin/history.db}"
  if [[ ! -f "$atuin_db" ]]; then
    warn "no atuin database at $atuin_db — has a shell with the hook ever run?"
  elif command -v sqlite3 >/dev/null 2>&1; then
    rows="$(sqlite3 "$atuin_db" 'select count(*) from history;' 2>/dev/null || echo 0)"
    if [[ "${rows:-0}" -gt 0 ]]; then
      ok "atuin has recorded history ($rows commands)"
    else
      warn "atuin database is empty — is the hook loaded?"
    fi
  else
    # No sqlite3: fall back to the file growing at all.
    [[ -s "$atuin_db" ]] && ok "atuin database is non-empty (install sqlite3 for a row count)" \
                         || warn "atuin database is empty — is the hook loaded?"
  fi
fi

# -----------------------------------------------------------------------------
if is_macos; then
  hdr "Running processes"
  for p in Hammerspoon AeroSpace karabiner_grabber espanso borders; do
    pgrep -qi "$p" && ok "$p running" || warn "$p not running"
  done
fi

# -----------------------------------------------------------------------------
hdr "Config validity"

for f in bashrc bash_profile; do
  "$BASH_BIN" -n "$DOTFILES/configs/$f" 2>/dev/null \
    && ok "$f parses" || bad "$f has a syntax error"
done

"$BASH_BIN" -n "$DOTFILES/install.sh" 2>/dev/null \
  && ok "install.sh parses" || bad "install.sh has a syntax error"

if command -v zsh >/dev/null 2>&1; then
  zsh -n "$DOTFILES/configs/zshrc" 2>/dev/null \
    && ok "zshrc parses" || bad "zshrc has a syntax error"
fi

if command -v starship >/dev/null 2>&1; then
  # starship keeps invalid format strings as valid TOML and only complains at
  # render time, so parsing the file is not enough — render it and check stderr.
  # Literal parens in a format string must be backslash-escaped: unescaped, the
  # module silently renders nothing.
  if STARSHIP_CONFIG="$SHIP" starship prompt 2>&1 >/dev/null | grep -qi 'warn\|error'; then
    bad "starship.toml has a module error — run: STARSHIP_CONFIG=$SHIP starship prompt >/dev/null"
  else
    ok "starship.toml renders without warnings"
  fi
fi

if command -v python3 >/dev/null 2>&1 && is_macos; then
  python3 -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" \
    "$DOTFILES/configs/aerospace.toml" 2>/dev/null \
    && ok "aerospace.toml is valid TOML" || bad "aerospace.toml is not valid TOML"

  # A bare `key = value` inside an [[on-window-detected]] table array silently
  # becomes part of THAT table instead of [mode.*.binding]. It stays valid TOML,
  # so nothing errors — the keybinding just never fires. So walk the file
  # tracking the enclosing table, and flag any key inside a window-rule block
  # that is not one of the keys such a block legitimately takes.
  stray="$(awk '
    /^[[:space:]]*\[/ { tbl = $0; next }
    /^[[:space:]]*[A-Za-z0-9_-]+([.][A-Za-z0-9_-]+)*[[:space:]]*=/ {
      if (tbl ~ /on-window-detected/) {
        key = $1
        if (key !~ /^(if[.]|run$|check-further-callbacks$)/) print NR ": " $0
      }
    }
  ' "$DOTFILES/configs/aerospace.toml")"
  if [[ -n "$stray" ]]; then
    bad "a binding sits inside an [[on-window-detected]] block in aerospace.toml — it will never fire:"
    printf '      %s\n' "$stray"
  else
    ok "all aerospace bindings are outside the [[on-window-detected]] blocks"
  fi
fi

if is_macos && command -v goku >/dev/null 2>&1; then
  goku --dry-run >/dev/null 2>&1 && ok "karabiner.edn compiles" \
                                 || warn "karabiner.edn may not compile — run: goku"
fi

if command -v aerospace >/dev/null 2>&1; then
  aerospace list-workspaces --all >/dev/null 2>&1 \
    && ok "aerospace responding" || warn "aerospace not responding"
fi

# -----------------------------------------------------------------------------
hdr "Drift"

if is_macos && command -v brew >/dev/null 2>&1; then
  # Use the exit code, not the message text: `brew bundle check` exits 1 when
  # anything is unsatisfied and its wording has changed between versions. It
  # also reports installed-but-outdated as unmet, so a large count is usually
  # upgrades, not missing software.
  if brew bundle check --file="$DOTFILES/Brewfile" >/dev/null 2>&1; then
    ok "Brewfile satisfied"
  else
    n="$(brew bundle check --file="$DOTFILES/Brewfile" --verbose 2>&1 | grep -c '^→' || true)"
    warn "Brewfile drift ($n unmet) — run: brew bundle install --file=$DOTFILES/Brewfile --no-upgrade"
  fi
fi

if [[ -d "$DOTFILES/.git" ]]; then
  if [[ -n "$(git -C "$DOTFILES" status --porcelain)" ]]; then
    warn "uncommitted changes in the repo"
  else
    ok "repo clean"
  fi
fi

# -----------------------------------------------------------------------------
printf '\n\033[1m%d passed, %d warnings, %d failures\033[0m\n' "$PASS" "$WARN" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
