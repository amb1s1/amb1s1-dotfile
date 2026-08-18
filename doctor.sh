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
#   ./doctor.sh            everything: repo contents AND this machine's state
#   ./doctor.sh --static   only checks that read the repo, never $HOME or
#                          installed tools. This is what CI runs — it needs no
#                          Mac, no installed tooling and no linked dotfiles, so
#                          the invariants live here once instead of being
#                          duplicated into a workflow file that drifts.
#
# Display strings below use a literal "~/" as a readable label; they are never
# used as paths (real path handling always goes through "$HOME"), so SC2088 is
# not a defect here.
# shellcheck disable=SC2088
set -uo pipefail

STATIC=false
case "${1:-}" in
  --static) STATIC=true ;;
  "") ;;
  -h | --help) sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

# True when checks that touch live machine state should run.
live() { ! $STATIC; }

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; WARN=0

ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  \033[1;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[1;33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
hdr()  { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

BASHRC="$DOTFILES/configs/bashrc"
SHIP="$DOTFILES/configs/starship.toml"

# =============================================================================
# LIVE CHECKS — this machine's state. Skipped by --static.
# =============================================================================
if live; then

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
check_link ".gitconfig"                "configs/gitconfig"
check_link ".config/atuin/config.toml" "configs/atuin.toml"

if is_macos; then
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

fi   # end live-only block (symlinks / machine-specific / generated artefacts)

# -----------------------------------------------------------------------------
hdr "Secrets"

if live; then
  if [[ -f "$HOME/.config/bash/secrets.sh" ]]; then
    if is_macos; then perms="$(stat -f '%Lp' "$HOME/.config/bash/secrets.sh")"
    else perms="$(stat -c '%a' "$HOME/.config/bash/secrets.sh")"; fi
    [[ "$perms" == "600" ]] && ok "secrets.sh present, mode 600" \
                            || bad "secrets.sh is mode $perms — should be 600"
  else
    warn "no ~/.config/bash/secrets.sh (fine if you use 1Password CLI instead)"
  fi
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
# Overridable so CI can supply the list from a secret rather than from $HOME.
DENYLIST="${DOTFILES_DENYLIST:-$HOME/.config/dotfiles/denylist}"
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

# The hook is per-clone (.git/hooks is not tracked), so a fresh clone in CI has
# none by definition — checking for it there would be noise.
if live; then
  if [[ -x "$DOTFILES/.git/hooks/pre-commit" ]]; then
    ok "gitleaks pre-commit hook installed"
  else
    warn "no pre-commit hook — a secret could be committed by accident"
  fi
fi

# -----------------------------------------------------------------------------
if live; then
hdr "Tools on PATH"

for t in git starship atuin fzf rg bat eza fd zoxide delta; do
  command -v "$t" >/dev/null 2>&1 && ok "$t" || warn "$t not on PATH"
done

if is_macos; then
  for t in brew fish goku espanso; do
    command -v "$t" >/dev/null 2>&1 && ok "$t" || warn "$t not on PATH"
  done
  [[ -d /Applications/Hammerspoon.app ]] && ok "Hammerspoon.app" \
                                         || warn "Hammerspoon.app missing"
fi
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

  # starship then atuin: atuin must come LAST, or starship's PROMPT_COMMAND can
  # be clobbered. ble.sh was part of this ordering until it was removed along
  # with brush; what remains still matters.
  ship_line="$(grep -n 'starship init bash' "$BASHRC" | head -1 | cut -d: -f1)"
  atuin_line="$(grep -n 'atuin init bash' "$BASHRC" | head -1 | cut -d: -f1)"
  if [[ -n "$ship_line" && -n "$atuin_line" ]] && (( ship_line < atuin_line )); then
    ok "starship -> atuin order is correct"
  else
    bad "shell integration order is wrong — atuin history recording will break"
  fi
fi

if [[ -r "$DOTFILES/configs/bash_profile" ]]; then
  grep -q 'source ~/.bashrc' "$DOTFILES/configs/bash_profile" \
    && ok ".bash_profile sources .bashrc (macOS opens login shells)" \
    || bad ".bash_profile does not source .bashrc — nothing will load on macOS"
fi

# --- Ghostty's shell: a REPO-CONTENT check, so it runs under --static ---------
#
# Which shell Ghostty launches decides whether atuin's ctrl-r is reachable at
# all. It needs no Mac and nothing installed — it reads configs/ghostty.
gcfg="$DOTFILES/configs/ghostty"
if [[ -r "$gcfg" ]]; then
  cmdline="$(grep -E '^\s*command\s*=' "$gcfg" | head -1)"
  if [[ "$cmdline" == *fish* ]]; then
    # fish is the macOS default: atuin ships a first-class fish backend and binds
    # ctrl-r in every mode, unlike bash where atuin skips vi-NORMAL. See
    # invariant 4.
    ok "Ghostty launches fish — atuin's native fish backend binds ctrl-r in every mode"
  elif [[ "$cmdline" == *bash* ]]; then
    ok "Ghostty launches bash — readline is present, so atuin's ctrl-r can bind"
    warn "  note: in vi mode atuin skips vi-NORMAL; fzf claims ctrl-r there unless rebound"
  else
    warn "Ghostty launches neither fish nor bash (currently: ${cmdline:-unset})"
  fi
fi

# shell-integration must name the SAME shell as `command`, or Ghostty emits the
# wrong integration script and OSC 133 command marks are silently lost — which
# also breaks notify-on-command-finish.
if [[ -r "$gcfg" ]]; then
  si="$(grep -E '^[[:space:]]*shell-integration[[:space:]]*=' "$gcfg" | head -1 | sed 's/.*=[[:space:]]*//')"
  cmdsh="$(basename "$(printf '%s' "${cmdline#*=}" | sed 's/^[[:space:]]*//' | cut -d' ' -f1)")"
  case "$cmdsh:$si" in
    fish:fish | bash:bash | zsh:zsh | *:detect)
      ok "shell-integration ($si) matches the launched shell ($cmdsh)" ;;
    *)
      bad "shell-integration is '$si' but Ghostty launches '$cmdsh' — OSC 133 marks will be lost" ;;
  esac
fi

# --- Ghostty's LOADED config: does Ghostty actually use the repo's file? ------
#
# The assertion above reads configs/ghostty, which is right for --static but
# blind to something that actually happened here: on macOS Ghostty ALSO reads
#   ~/Library/Application Support/com.mitchellh.ghostty/config
# and that file's scalars WIN. A stale one there set `command = fish`, so Ghostty
# launched fish for weeks while the check above confirmed the repo's intent.
# Reading the repo file proves what we intend, not what runs, so
# ask Ghostty what it resolved. Same lesson as the driver-extension check.
if live && is_macos; then
  ghostty_bin=""
  if command -v ghostty >/dev/null 2>&1; then
    ghostty_bin="$(command -v ghostty)"
  elif [[ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]]; then
    ghostty_bin=/Applications/Ghostty.app/Contents/MacOS/ghostty
  fi

  if [[ -n "$ghostty_bin" ]]; then
    loaded="$("$ghostty_bin" +show-config 2>/dev/null || true)"
    livecmd="$(printf '%s\n' "$loaded" | grep -E '^command = ' | head -1)"
    livecmd="${livecmd#command = }"

    # Compare LOADED against the repo rather than hardcoding a shell name, so
    # this keeps working whichever shell the repo settles on and still catches a
    # shadowing file substituting a different one.
    repocmd="$(grep -E '^[[:space:]]*command[[:space:]]*=' "$gcfg" 2>/dev/null \
               | head -1 | sed 's/.*=[[:space:]]*//')"
    if [[ -z "$livecmd" ]]; then
      bad "Ghostty's loaded config sets no command — it will launch your login shell, not the configured one"
    elif [[ -n "$repocmd" && "$livecmd" == "$repocmd" ]]; then
      ok "Ghostty's LOADED command matches the repo ($(basename "${livecmd%% *}"))"
    else
      bad "Ghostty loads a different command than configs/ghostty specifies:"
      printf '      loaded: %s\n' "$livecmd"
      printf '      repo:   %s\n' "${repocmd:-unset}"
      printf '      a config in ~/Library/Application Support/com.mitchellh.ghostty/\n'
      printf '      overrides configs/ghostty; rename it to stop that.\n'
    fi

    # The palette too, so a shadowing file cannot silently revert the theme.
    livetheme="$(printf '%s\n' "$loaded" | grep -E '^theme = ' | head -1)"
    livetheme="${livetheme#theme = }"
    repotheme="$(grep -E '^[[:space:]]*theme[[:space:]]*=' "$gcfg" 2>/dev/null \
                 | head -1 | sed 's/.*=[[:space:]]*//')"
    if [[ -n "$repotheme" && "$livetheme" == "$repotheme" ]]; then
      ok "Ghostty's loaded theme matches the repo ($repotheme)"
    else
      warn "Ghostty's loaded theme is '${livetheme:-unset}', the repo says '${repotheme:-unset}'"
    fi

    # Can the shell Ghostty launches actually BIND ctrl-r? Every other atuin
    # check here proves it RECORDS; none proved its search was reachable, and for
    # a while it was not: brush accepted the binding and registered nothing, so
    # ctrl-r searched a 31-line history while 8000 commands sat in atuin. brush is
    # no longer installed; the lesson is why fish is the default. See invariant 4.
    shellbin="$livecmd"; shellbin="${shellbin%% *}"
    case "$(basename "$shellbin")" in
      bash)
        # Scope note: this proves bash SUPPORTS readline bindings, not that atuin
        # is bound in a live session. It cannot prove the latter — a `-c` shell
        # engages no line editor. Check by hand in the shell: bind -p | grep C-r
        if [[ -x "$shellbin" ]]; then
          nbind="$("$shellbin" -c 'bind -p 2>/dev/null | wc -l' 2>/dev/null | tr -d '[:space:]' || echo 0)"
          if [[ "${nbind:-0}" -gt 0 ]]; then
            ok "bash supports readline bindings ($nbind) — atuin's ctrl-r can attach"
          else
            bad "bash registers NO readline bindings — atuin's ctrl-r can never attach"
          fi
        fi
        ;;
      fish | zsh)
        # atuin ships native backends for both, and they bind ctrl-r their own
        # way (fish's own `bind`, zsh's `bindkey`). `bind -p` is not their
        # interface, so running it would report a failure that is not real.
        ok "$(basename "$shellbin") has a native atuin backend — atuin init binds ctrl-r"
        ;;
      *)
        warn "unrecognised shell '$(basename "$shellbin")' — cannot tell whether atuin's ctrl-r binds"
        ;;
    esac
  fi
fi

BASH_BIN="$(command -v bash)"

if live; then
  if is_macos; then
    BREW_BASH="$(brew --prefix 2>/dev/null || echo /opt/homebrew)/bin/bash"
    if [[ -x "$BREW_BASH" ]]; then
      BASH_BIN="$BREW_BASH"
      bver="$("$BREW_BASH" -c 'echo ${BASH_VERSINFO[0]}')"
      (( bver >= 4 )) && ok "Homebrew bash $("$BREW_BASH" -c 'echo $BASH_VERSION')" \
                      || bad "Homebrew bash is v$bver — parts of .bashrc need 4.0+"
    else
      bad "no $BREW_BASH — system /bin/bash 3.2 is too old for parts of .bashrc"
    fi
  fi

  if is_macos; then
    # bash is the login shell; fish is interactive-only, launched by Ghostty.
    login_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    case "$login_shell" in
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
fi

# Does atuin actually record? The order above is necessary but not sufficient,
# and a silent failure here means you lose history without noticing.
#
# Query the SQLite database directly rather than going through the atuin CLI.
# Every atuin read subcommand (`history list`, `search`, `stats`) refuses to run
# without $ATUIN_SESSION in the environment, which only an initialised
# interactive shell sets — so from a script they all fail even when recording is
# working perfectly. `history list --limit` does not exist at all as of 18.19.
if live && command -v atuin >/dev/null 2>&1; then
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
if live && is_macos; then
  hdr "Running processes"
  for p in Hammerspoon espanso; do
    pgrep -qi "$p" && ok "$p running" || warn "$p not running"
  done
  # Karabiner-Elements 16 dropped karabiner_grabber; the equivalent process is
  # now Karabiner-Core-Service. Checking only the old name warned on every run
  # against a healthy 16.x install. Accept either, so this stays honest if you
  # ever roll back to 15.x.
  if pgrep -qi 'Karabiner-Core-Service|karabiner_grabber'; then
    ok "Karabiner core service running"
  else
    warn "Karabiner core service not running"
  fi
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

# Literal parens in a starship format string MUST be backslash-escaped: `(` opens
# a conditional group, so unescaped the module renders nothing at all while the
# TOML stays valid.
#
# Two checks, because each catches what the other misses.
#
# (a) A direct pattern check. Works with or without starship installed, which
#     matters in CI, and cannot pass vacuously. `[\(]` is correct; a bare `[(]`
#     or `[)]` as a whole style-group body is the bug.
if grep -nE '^[[:space:]]*format[[:space:]]*=.*\[[()]\]' "$SHIP" >/dev/null 2>&1; then
  bad "starship.toml has an UNESCAPED literal paren in a format string — the module will render nothing:"
  grep -nE '^[[:space:]]*format[[:space:]]*=.*\[[()]\]' "$SHIP" | sed 's/^/      /'
else
  ok "starship.toml literal parens are escaped"
fi

# (a2) The same trap, different character: a literal "$" in a git_status
#      indicator. starship reads an unescaped $ as the start of a variable name,
#      fails to parse that sub-format, and renders the indicator as NOTHING.
#      `stashed = "$"` shipped broken for exactly this reason — and the render
#      check below could not catch it, because git_status only evaluates its
#      `stashed` sub-format in a repository that HAS a stash, and this repo has
#      none. So check it statically, where no stash is required.
#
#      ${count} / ${ahead_count} are genuine variables and must pass.
bad_dollar="$(awk '
  /^\[git_status\]/ { inblk = 1; next }
  /^\[/             { inblk = 0 }
  inblk && /=/ {
    v = $0
    sub(/^[^=]*=[[:space:]]*/, "", v)
    gsub(/\\\$/, "", v)                              # escaped \$ is correct
    gsub(/\$\{[A-Za-z_][A-Za-z_0-9]*\}/, "", v)        # ${count}
    gsub(/\$[A-Za-z_][A-Za-z_0-9]*/, "", v)            # $all_status
    if (v ~ /\$/) printf "%d: %s\n", NR, $0
  }
' "$SHIP")"
if [[ -n "$bad_dollar" ]]; then
  bad "starship.toml git_status has an UNESCAPED literal \$ — that indicator renders nothing:"
  printf '      %s\n' "$bad_dollar"
else
  ok "starship.toml git_status literal \$ is escaped"
fi

# (b) Render it and read stderr, which catches malformed formats generally.
#
#     --path matters: starship only evaluates a module when its trigger
#     condition holds, so git_branch is skipped entirely outside a git
#     repository. Rendering from an arbitrary cwd therefore passes vacuously —
#     the exact reason an earlier version of this check missed a real unescaped
#     paren. Point it at $DOTFILES, which is a git repo, so the git modules run.
if command -v starship >/dev/null 2>&1; then
  if STARSHIP_CONFIG="$SHIP" starship prompt --path "$DOTFILES" 2>&1 >/dev/null \
       | grep -qiE 'warn|error'; then
    bad "starship.toml has a module error — run: STARSHIP_CONFIG=$SHIP starship prompt --path $DOTFILES >/dev/null"
  else
    ok "starship.toml renders without warnings"
  fi
fi


if live && is_macos && command -v goku >/dev/null 2>&1; then
  # goku exits 1 whether it succeeded or not, so its exit status says nothing —
  # testing it warned "may not compile" on every run even with a valid .edn.
  # What actually distinguishes the two: on success goku writes the compiled
  # profile to stdout and nothing to stderr; on failure stdout is empty and the
  # error goes to stderr. So test stdout, not $?.
  [ -n "$(goku --dry-run 2>/dev/null)" ] && ok "karabiner.edn compiles" \
                                         || warn "karabiner.edn may not compile — run: goku"
fi

# Karabiner's virtual HID driver has to be approved by hand — macOS offers no
# CLI for it, by design. Unapproved, Karabiner remaps NOTHING and never writes
# karabiner.json, which previously surfaced only as a confusing "karabiner.json
# absent". The state is machine-readable, so read it and say what to click.
if live && is_macos && command -v systemextensionsctl >/dev/null 2>&1; then
  drv="$(systemextensionsctl list 2>/dev/null \
         | grep -i 'Karabiner-DriverKit-VirtualHIDDevice' | head -1 || true)"
  if [[ -z "$drv" ]]; then
    warn "Karabiner driver extension not installed — reinstall the cask, then launch the app once"
  elif [[ "$drv" == *"waiting for user"* ]]; then
    warn "Karabiner driver extension is NOT approved — nothing will remap until it is:"
    printf '      System Settings > General > Login Items & Extensions >\n'
    printf '      Driver Extensions > enable Karabiner-Elements\n'
  else
    ok "Karabiner driver extension approved"
  fi
fi


# -----------------------------------------------------------------------------
if live; then
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

fi   # end live-only Drift section

# -----------------------------------------------------------------------------
if $STATIC; then
  printf '\n\033[2m(--static: skipped every check that reads $HOME or installed tools)\033[0m\n'
fi
printf '\033[1m%d passed, %d warnings, %d failures\033[0m\n' "$PASS" "$WARN" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
