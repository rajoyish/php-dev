# ─────────────────────────────────────────────────────────────────────────────
# devenv — switch the local PHP stack between Laravel Herd and Flock
#
#   devenv herd      Herd (nginx, dnsmasq, php-fpm) + DBngin MySQL
#   devenv flock     Flock daemon (web, DNS, php-fpm, mail, dumps) + Flock MySQL
#   devenv toggle    switch to whichever one isn't active
#   devenv status    show what's active, what's on the ports, and `which php`
#
#   Shortcuts: use-herd, use-flock, devswitch, devstatus
#
# Only one stack can run at a time: both use ports 80/443, 2525 (mail) and
# 3306 (MySQL), and both want the .test DNS resolver. Projects live in
# $DEVENV_SITES, which is parked in both apps.
# ─────────────────────────────────────────────────────────────────────────────

export DEVENV_SITES="${DEVENV_SITES:-/Volumes/Sites}"
export DEVENV_STATE="${DEVENV_STATE:-$HOME/.config/devenv/active}"

typeset -g _DE_HERD_APP="/Applications/Herd.app"
typeset -g _DE_FLOCK_APP="/Applications/Flock.app"
typeset -g _DE_HERD_BIN="$HOME/Library/Application Support/Herd/bin"
typeset -g _DE_HERD_CLI="$_DE_HERD_BIN/herd"
typeset -g _DE_HERD_VALET="$HOME/Library/Application Support/Herd/config/valet/config.json"
typeset -g _DE_FLOCK_HOME="$HOME/Library/Application Support/Flock"
typeset -g _DE_FLOCK_BIN="$_DE_FLOCK_HOME/bin"
typeset -g _DE_FLOCK_CLI="$_DE_FLOCK_BIN/flock"
typeset -g _DE_FLOCK_LABEL="dev.flock.daemon"
typeset -g _DE_FLOCK_PLIST="$HOME/Library/LaunchAgents/dev.flock.daemon.plist"
typeset -g _DE_FLOCK_API="http://127.0.0.1:53531"
typeset -g _DE_DBNGIN_DIR="$HOME/Library/Application Support/com.tinyapp.DBngin/Engines/mysql"
typeset -g _DE_RESOLVER="/etc/resolver/test"

# ── small helpers ────────────────────────────────────────────────────────────

_de_say()  { print -P "%F{cyan}›%f $*"; }
_de_ok()   { print -P "%F{green}✓%f $*"; }
_de_warn() { print -P "%F{yellow}!%f $*"; }
_de_err()  { print -P "%F{red}✗%f $*" >&2; }

# PID listening on a TCP port (empty if none)
_de_port_pid() { lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | head -n 1; }

# _de_wait_port <port> <up|down> [seconds]
_de_wait_port() {
  local port=$1 want=$2 i
  for (( i = 0; i < ${3:-20} * 4; i++ )); do
    if [[ $want == up ]]; then [[ -n $(_de_port_pid $port) ]] && return 0
    else                       [[ -z $(_de_port_pid $port) ]] && return 0
    fi
    sleep 0.25
  done
  return 1
}

_de_flock_token() {
  grep -o '"token": *"[^"]*"' "$_DE_FLOCK_HOME/api.json" 2>/dev/null | cut -d'"' -f4
}

# _de_flock_service <name> <start|stop>
_de_flock_service() {
  local token=$(_de_flock_token)
  [[ -z $token ]] && return 1
  curl -fs -m 30 -X POST -H "Authorization: Bearer $token" \
    "$_DE_FLOCK_API/v1/services/$1/$2" >/dev/null 2>&1
}

_de_dbngin_plist() {
  find "$_DE_DBNGIN_DIR" -name "com.tinyapp.DBngin.mysqld-*.plist" 2>/dev/null | head -n 1
}

_de_app_running() { pgrep -xq "$1"; }

# Point /etc/resolver/test at the right DNS server (asks for sudo only if needed)
# _de_resolver <herd|flock>
_de_resolver() {
  local want
  if [[ $1 == flock ]]; then
    want=$'# Managed by Flock\nnameserver 127.0.0.1\nport 53535'
    grep -q '^port 53535' "$_DE_RESOLVER" 2>/dev/null && return 0
  else
    want='nameserver 127.0.0.1'
    [[ -f $_DE_RESOLVER ]] && ! grep -q '^port ' "$_DE_RESOLVER" && return 0
  fi
  _de_say "Pointing .test DNS at ${1:u} (sudo needed for $_DE_RESOLVER)"
  print -r -- "$want" | sudo tee "$_DE_RESOLVER" >/dev/null \
    && sudo killall -HUP mDNSResponder 2>/dev/null
}

# ── PATH: put the active stack's php/composer/node shims first ───────────────

_devenv_apply_path() {
  local active=${1:-$(<"$DEVENV_STATE" 2>/dev/null)}
  [[ -z $active ]] && return
  local p; local -a keep
  for p in $path; do
    [[ ${p%/} == "$_DE_HERD_BIN" || ${p%/} == "$_DE_FLOCK_BIN" ]] && continue
    keep+=("$p")
  done
  case $active in
    herd)  path=("$_DE_HERD_BIN" $keep) ;;
    flock) path=("$_DE_FLOCK_BIN" $keep) ;;
  esac
  typeset -g _DEVENV_APPLIED=$active
  rehash
}

# Other open terminals follow a switch at their next prompt.
_devenv_precmd() {
  local active=$(<"$DEVENV_STATE" 2>/dev/null)
  [[ -n $active && $active != $_DEVENV_APPLIED ]] && _devenv_apply_path "$active"
}

# ── stop / start each stack ──────────────────────────────────────────────────

_de_stop_flock() {
  _de_say "Stopping Flock…"
  _de_flock_service mysql stop
  _de_app_running FlockBar && osascript -e 'quit app "Flock"' >/dev/null 2>&1
  sleep 0.5; pkill -x FlockBar 2>/dev/null
  # Disable so it doesn't come back (KeepAlive) or start at login while Herd is active.
  launchctl disable "gui/$UID/$_DE_FLOCK_LABEL" 2>/dev/null
  launchctl bootout "gui/$UID/$_DE_FLOCK_LABEL" 2>/dev/null
  _de_wait_port 80 down 15 || { _de_err "Port 80 still busy after stopping Flock"; return 1; }
  _de_ok "Flock stopped"
}

_de_stop_herd() {
  _de_say "Stopping Herd…"
  if _de_app_running Herd; then
    "$_DE_HERD_CLI" stop >/dev/null 2>&1
    osascript -e 'quit app "Herd"' >/dev/null 2>&1
  fi
  local plist=$(_de_dbngin_plist)
  [[ -n $plist ]] && launchctl unload "$plist" 2>/dev/null
  _de_wait_port 80 down 15   || { _de_err "Port 80 still busy after stopping Herd"; return 1; }
  _de_wait_port 3306 down 10 || _de_warn "Port 3306 still busy (DBngin MySQL)"
  _de_ok "Herd + DBngin MySQL stopped"
}

_de_start_flock() {
  _de_say "Starting Flock…"
  launchctl enable "gui/$UID/$_DE_FLOCK_LABEL" 2>/dev/null
  launchctl bootstrap "gui/$UID" "$_DE_FLOCK_PLIST" 2>/dev/null
  launchctl kickstart "gui/$UID/$_DE_FLOCK_LABEL" 2>/dev/null
  open -g "$_DE_FLOCK_APP"
  _de_wait_port 53531 up 30 || { _de_err "Flock daemon didn't come up (see: flock logs daemon)"; return 1; }
  _de_wait_port 80 up 20     || _de_warn "Flock web server isn't listening on :80 yet"

  _de_say "Starting Flock MySQL…"
  if _de_flock_service mysql start && _de_wait_port 3306 up 30; then
    _de_ok "Flock MySQL on :3306"
  else
    _de_warn "Flock MySQL didn't start (try: flock services)"
  fi

  if [[ -d $DEVENV_SITES ]] && ! grep -qF "\"$DEVENV_SITES\"" "$_DE_FLOCK_HOME/config.json" 2>/dev/null; then
    "$_DE_FLOCK_CLI" park "$DEVENV_SITES" >/dev/null && _de_ok "Parked $DEVENV_SITES in Flock"
  fi
  _de_resolver flock
  _de_ok "Flock running"
}

_de_start_herd() {
  _de_say "Starting DBngin MySQL…"
  local plist=$(_de_dbngin_plist)
  if [[ -z $plist ]]; then
    _de_warn "DBngin MySQL plist not found in $_DE_DBNGIN_DIR"
  else
    launchctl load "$plist" 2>/dev/null
    _de_wait_port 3306 up 20 && _de_ok "DBngin MySQL on :3306" || _de_warn "DBngin MySQL didn't start"
  fi

  _de_say "Starting Herd…"
  open -g "$_DE_HERD_APP"
  _de_wait_port 2304 up 40 || { _de_err "Herd app didn't come up"; return 1; }
  "$_DE_HERD_CLI" start >/dev/null 2>&1
  _de_wait_port 80 up 20 || _de_warn "Herd nginx isn't listening on :80 yet"

  if [[ -d $DEVENV_SITES ]] && ! grep -qF "${DEVENV_SITES//\//\\/}" "$_DE_HERD_VALET" 2>/dev/null; then
    "$_DE_HERD_CLI" park "$DEVENV_SITES" >/dev/null 2>&1 && _de_ok "Parked $DEVENV_SITES in Herd"
  fi
  _de_resolver herd
  _de_ok "Herd running"
}

# ── status ───────────────────────────────────────────────────────────────────

_de_port_owner() {
  local pid=$(_de_port_pid $1)
  [[ -z $pid ]] && { print "free"; return; }
  local cmd=$(ps -p $pid -o args= 2>/dev/null)
  case $cmd in
    *Flock*)              print "Flock (pid $pid)" ;;
    *DBngin*)             print "DBngin (pid $pid)" ;;
    *Herd*|*nginx*)       print "Herd (pid $pid)" ;;
    *)                    print "${cmd[1,60]} (pid $pid)" ;;
  esac
}

# Prompt-style print that drops colour when piped or when NO_COLOR is set.
_de_p() {
  setopt localoptions extendedglob
  local s=$1
  if [[ ! -t 1 || -n $NO_COLOR ]]; then
    s=${s//\%[FK]\{[a-z0-9]##\}/}; s=${s//\%[fkBb]/}
  fi
  print -P -- "$s"
}

# Escape a value for print -P and shorten $HOME to ~.
_de_q() { local v=${1/#$HOME/\~}; print -r -- "${v//\%/%%}"; }

# _de_dot <ok|warn|off|bad>
_de_dot() {
  case $1 in
    ok)   print -r -- '%F{green}●%f' ;;
    warn) print -r -- '%F{yellow}●%f' ;;
    bad)  print -r -- '%F{red}✗%f' ;;
    *)    print -r -- '%F{8}○%f' ;;
  esac
}

# _de_row <icon> <label> <state> <value> [hint]
_de_row() {
  local hint=
  [[ -n $5 ]] && hint="  %F{8}$5%f"
  _de_p "  %F{cyan}$1%f  ${(r:10:)2}$(_de_dot $3) $4$hint"
}

# State of something that should belong to <expected>: ok, warn (someone else) or off (free)
_de_owned() {
  case $1 in
    free)   print off ;;
    $2*)    print ok ;;
    *)      print warn ;;
  esac
}

devenv-status() {
  local active=$(<"$DEVENV_STATE" 2>/dev/null)
  local stack=${(C)active} db bin
  case $active in
    herd)  db=DBngin; bin=$_DE_HERD_BIN ;;
    flock) db=Flock;  bin=$_DE_FLOCK_BIN ;;
  esac

  local web=$(_de_port_owner 80) mail=$(_de_port_owner 2525) mysql=$(_de_port_owner 3306)
  local dns=none
  [[ -f $_DE_RESOLVER ]] && { grep -q '^port 53535' $_DE_RESOLVER && dns=Flock || dns=Herd; }
  local php=$(whence -p php) composer=$(whence -p composer)
  local ver=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
  local -a fixes

  _de_p "%B⇄  Active stack:%b ${stack:-none set}"

  local s
  s=$(_de_owned "$web" "$stack");   _de_row '◎' web   $s "$(_de_q "$web")"   ':80'
  [[ $s == ok ]] || fixes+=("web on :80 isn't served by ${stack:-a stack} — run php-dev ${active:-toggle}")
  s=$(_de_owned "$mail" "$stack");  _de_row '✉' mail  $s "$(_de_q "$mail")"  ':2525'
  s=$(_de_owned "$mysql" "$db");    _de_row '▤' mysql $s "$(_de_q "$mysql")" ':3306'
  [[ $s == ok || -z $active ]] || fixes+=("MySQL on :3306 isn't $db — run php-dev mysql ${active/herd/dbngin}")
  s=$(_de_owned "$dns" "$stack");   _de_row '⌖' dns   $s "$dns" "$(_de_q "$_DE_RESOLVER")"
  [[ $s == ok ]] || fixes+=(".test DNS points at $dns — run php-dev ${active:-toggle} to fix")

  [[ -n $bin && ${php:h} == $bin ]] && s=ok || s=warn
  [[ -z $php ]] && s=bad
  _de_row '◆' php      $s "${ver:-not found}" "$(_de_q "$php")"
  [[ -n $bin && ${composer:h} == $bin ]] && s=ok || s=warn
  [[ -z $composer ]] && s=bad
  _de_row '◈' composer $s "$(_de_q "${composer:-not found}")"

  if [[ -d $DEVENV_SITES ]]; then
    _de_row '⌂' sites ok "$(_de_q "$DEVENV_SITES")"
  else
    _de_row '⌂' sites bad "$(_de_q "$DEVENV_SITES")" 'not mounted'
  fi

  if (( $#fixes )); then
    print
    for s in $fixes; do _de_p "%F{yellow}!%f $(_de_q "$s")"; done
  fi
}

# Kept from the old MySQL switcher: report who owns :3306
mysql-status() {
  local owner=$(_de_port_owner 3306)
  _de_row '▤' mysql "$(_de_owned "$owner" "${owner%% *}")" "$(_de_q "$owner")" ':3306'
}

# ── main command ─────────────────────────────────────────────────────────────

devenv() {
  local target=$1 current=$(<"$DEVENV_STATE" 2>/dev/null)

  case $target in
    status|"") devenv-status; return ;;
    toggle)    [[ $current == herd ]] && target=flock || target=herd ;;
    herd|flock) ;;
    *) print "usage: devenv [herd|flock|toggle|status]"; return 1 ;;
  esac

  if [[ $target == herd && ( ! -d $_DE_HERD_APP || ! -x $_DE_HERD_CLI ) ]]; then
    _de_err 'Install and open Laravel Herd before switching to it.'
    return 1
  elif [[ $target == flock && ( ! -d $_DE_FLOCK_APP || ! -x $_DE_FLOCK_CLI ) ]]; then
    _de_err 'Install and open Flock before switching to it.'
    return 1
  fi

  [[ -d $DEVENV_SITES ]] || _de_warn "$DEVENV_SITES isn't available — is the eSSD mounted?"

  print -P "%B⇄ Switching to ${target:u}%b"
  if [[ $target == herd ]]; then
    _de_stop_flock || return 1
    _de_start_herd || return 1
  else
    _de_stop_herd  || return 1
    _de_start_flock || return 1
  fi

  mkdir -p "${DEVENV_STATE:h}"
  print -r -- "$target" > "$DEVENV_STATE"
  _devenv_apply_path "$target"
  print
  devenv-status
}

alias use-herd='devenv herd'
alias use-flock='devenv flock'
alias devswitch='devenv toggle'
alias devstatus='devenv status'

# DB-only switch, without touching the web stack (from the old setup)
switch-mysql() {
  case ${1:-toggle} in
    dbngin) _de_flock_service mysql stop; _de_wait_port 3306 down 10
            launchctl load "$(_de_dbngin_plist)" 2>/dev/null ;;
    flock)  launchctl unload "$(_de_dbngin_plist)" 2>/dev/null; _de_wait_port 3306 down 10
            _de_flock_service mysql start ;;
    *)      [[ $(_de_port_owner 3306) == DBngin* ]] && switch-mysql flock || switch-mysql dbngin; return ;;
  esac
  _de_wait_port 3306 up 30; mysql-status
}

# ── init ─────────────────────────────────────────────────────────────────────

# First run: record whichever stack is actually serving right now.
if [[ ! -f $DEVENV_STATE ]]; then
  mkdir -p "${DEVENV_STATE:h}"
  if [[ $(_de_port_owner 80) == Herd* ]]; then print herd >| "$DEVENV_STATE"; else print flock >| "$DEVENV_STATE"; fi
fi

autoload -Uz add-zsh-hook
add-zsh-hook precmd _devenv_precmd
_devenv_apply_path

# Old MySQL-only command names still work
alias use-dbngin='switch-mysql dbngin'
alias use-flock-mysql='switch-mysql flock'
