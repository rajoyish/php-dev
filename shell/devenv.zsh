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

source "${${(%):-%x}:A:h}/icons.zsh"

# ── small helpers ────────────────────────────────────────────────────────────

_de_say()  { _de_p "$_DE_I[wait]$(_de_q "$*")"; }
_de_ok()   { _de_p "$_DE_I[ok]$(_de_q "$*")"; }
_de_warn() { _de_p "$_DE_I[warn]$(_de_q "$*")"; }
_de_err()  { _de_p "$_DE_I[err]$(_de_q "$*")" >&2; }

# PID listening on a TCP port (empty if none)
_de_port_pid() { lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | head -n 1; }

# _de_wait_port <port> <up|down> [seconds]
# Shows a spinner in a terminal while it waits.
_de_wait_port() {
  local port=$1 want=$2 i spin=0
  local -a frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  [[ -t 1 ]] && spin=1
  for (( i = 0; i < ${3:-20} * 4; i++ )); do
    if [[ $want == up && -n $(_de_port_pid $port) ]] || [[ $want == down && -z $(_de_port_pid $port) ]]; then
      (( spin && i )) && print -n '\r\e[K'
      return 0
    fi
    (( spin )) && print -n "\r   ${frames[i % 10 + 1]} waiting for :$port to come $want ($(( i / 4 ))s)"
    sleep 0.25
  done
  (( spin )) && print -n '\r\e[K'
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
  [[ $(_de_icon_style) == $_DE_ICON_STYLE ]] || _de_load_icons
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
  # Launch Herd first: the app takes longest, so it boots while MySQL starts.
  _de_say "Starting Herd and DBngin MySQL…"
  open -g "$_DE_HERD_APP"
  local plist=$(_de_dbngin_plist)
  if [[ -z $plist ]]; then
    _de_warn "DBngin MySQL plist not found in $_DE_DBNGIN_DIR"
  else
    launchctl load "$plist" 2>/dev/null
    _de_wait_port 3306 up 20 && _de_ok "DBngin MySQL on :3306" || _de_warn "DBngin MySQL didn't start"
  fi

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

# JSON string literal
_de_json() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\t'/\\t}; s=${s//$'\n'/\\n}
  print -rn -- "\"$s\""
}

# _de_dot <ok|warn|off|bad>
_de_dot() {
  case $1 in
    ok|warn|bad) print -rn -- "$_DE_I[dot_$1]" ;;
    *)           print -rn -- "$_DE_I[dot_off]" ;;
  esac
}

# _de_row <icon> <label> <state> <value> [hint]
# Row spacing: a blank line between the rows of a group, none before the first.
# Call _de_group after a heading; row helpers call _de_gap.
_de_group() { typeset -gi _DE_GAP=0; }
_de_gap()   { (( ${_DE_GAP:-0} )) && print; typeset -gi _DE_GAP=1; }

_de_row() {
  _de_gap
  local hint=
  [[ -n $5 ]] && hint="  %F{8}$5%f"
  _de_p "  $1${(r:10:)2}$(_de_dot $3)$4$hint"
}

# State of something that should belong to <expected>: ok, warn (someone else) or off (free)
_de_owned() {
  case $1 in
    free|none) print off ;;
    $2*)       print ok ;;
    *)         print warn ;;
  esac
}


# Gathers the stack's health into globals:
#   _de_active, _de_checks (ordered names), _de_state/_de_value/_de_hint (per check),
#   _de_issues (messages) and _de_fixes (php-dev arguments that repair each issue).
_de_collect() {
  typeset -g _de_active=$(<"$DEVENV_STATE" 2>/dev/null)
  typeset -ga _de_checks=(web mail mysql dns php composer sites) _de_issues=() _de_fixes=()
  typeset -gA _de_state=() _de_value=() _de_hint=()
  local stack=${(C)_de_active} db bin name port v
  case $_de_active in
    herd)  db=DBngin; bin=$_DE_HERD_BIN ;;
    flock) db=Flock;  bin=$_DE_FLOCK_BIN ;;
    *)     _de_issues+=("No stack is selected"); _de_fixes+=('') ;;
  esac

  for name port in web 80 mail 2525 mysql 3306; do
    v=$(_de_port_owner $port)
    _de_value[$name]=$v; _de_hint[$name]=":$port"
    if [[ $name == mysql ]]; then _de_state[$name]=$(_de_owned "$v" "$db")
    else                          _de_state[$name]=$(_de_owned "$v" "$stack"); fi
  done
  # Mail is optional (Herd's mail needs Herd Pro); only a foreign owner is a problem.
  [[ $_de_state[mail] == off ]] && _de_state[mail]=ok _de_value[mail]='not running'

  v=none
  [[ -f $_DE_RESOLVER ]] && { grep -q '^port 53535' $_DE_RESOLVER && v=Flock || v=Herd; }
  _de_value[dns]=$v; _de_hint[dns]=$_DE_RESOLVER
  _de_state[dns]=$(_de_owned "$v" "$stack")

  v=$(whence -p php)
  _de_value[php]=$(php -r 'echo PHP_VERSION;' 2>/dev/null); _de_hint[php]=$v
  [[ -n $bin && ${v:h} == $bin ]] && _de_state[php]=ok || _de_state[php]=warn
  [[ -z $v ]] && _de_state[php]=bad _de_value[php]='not found'

  v=$(whence -p composer)
  _de_value[composer]=${v:-not found}
  [[ -n $bin && ${v:h} == $bin ]] && _de_state[composer]=ok || _de_state[composer]=warn
  [[ -z $v ]] && _de_state[composer]=bad

  _de_value[sites]=$DEVENV_SITES
  if [[ -d $DEVENV_SITES ]]; then _de_state[sites]=ok
  else _de_state[sites]=bad _de_hint[sites]='not mounted'; fi

  [[ -z $_de_active ]] && return
  if [[ $_de_state[web] != ok ]]; then
    _de_issues+=("Port :80 isn't served by $stack ($_de_value[web])"); _de_fixes+=($_de_active)
  fi
  # When the web stack is wrong, its mail port is too; one switch fixes both.
  if [[ $_de_state[mail] != ok && $_de_state[web] == ok ]]; then
    _de_issues+=("Port :2525 is held by $_de_value[mail]"); _de_fixes+=($_de_active)
  fi
  if [[ $_de_state[mysql] != ok ]]; then
    _de_issues+=("MySQL on :3306 isn't $db ($_de_value[mysql])"); _de_fixes+=("mysql ${_de_active/herd/dbngin}")
  fi
  if [[ $_de_state[dns] != ok ]]; then
    _de_issues+=(".test DNS points at $_de_value[dns], not $stack"); _de_fixes+=($_de_active)
  fi
  if [[ $_de_state[php] != ok || $_de_state[composer] != ok ]]; then
    _de_issues+=("php or composer doesn't come from $stack's bin directory"); _de_fixes+=('path')
  fi
  if [[ $_de_state[sites] != ok ]]; then
    _de_issues+=("$DEVENV_SITES isn't available — mount the drive or set DEVENV_SITES"); _de_fixes+=('')
  fi
}

# Describe a fix as the command a person would type.
_de_fix_text() {
  case $1 in
    '')   print -r -- '' ;;
    path) print -r -- 'open a new terminal (or run rehash)' ;;
    *)    print -r -- "php-dev $1" ;;
  esac
}

_de_status_json() {
  local name i
  print -n '{"stack":'; _de_json "$_de_active"
  print -n ",\"healthy\":$( (( $#_de_issues )) && print -n false || print -n true),\"checks\":{"
  for name in $_de_checks; do
    [[ $name == $_de_checks[1] ]] || print -n ,
    _de_json $name; print -n ':{"state":'; _de_json "$_de_state[$name]"
    print -n ',"value":'; _de_json "$_de_value[$name]"
    print -n ',"detail":'; _de_json "$_de_hint[$name]"; print -n '}'
  done
  print -n '},"issues":['
  for (( i = 1; i <= $#_de_issues; i++ )); do
    (( i > 1 )) && print -n ,
    print -n '{"message":'; _de_json "$_de_issues[i]"
    print -n ',"fix":'; _de_json "$(_de_fix_text "$_de_fixes[i]")"; print -n '}'
  done
  print ']}'
}

# _de_print_issues: list issues with the command that fixes each
_de_print_issues() {
  local i fix
  for (( i = 1; i <= $#_de_issues; i++ )); do
    fix=$(_de_fix_text "$_de_fixes[i]")
    [[ -n $fix ]] && fix="  %F{8}→ $(_de_q "$fix")%f"
    _de_gap
    _de_p "  $_DE_I[dot_warn]$(_de_q "$_de_issues[i]")$fix"
  done
}

devenv-status() {
  _de_collect
  if [[ $1 == --json ]]; then _de_status_json; return; fi

  local name value hint
  _de_p "$_DE_I[switch]%BActive stack:%b ${${(C)_de_active}:-none set}"
  print
  _de_group
  for name in $_de_checks; do
    value=$_de_value[$name] hint=$_de_hint[$name]
    if [[ $name == php ]]; then hint=$(_de_q "$hint"); else value=$(_de_q "$value"); fi
    [[ $name == dns ]] && hint=$(_de_q "$hint")
    _de_row "$_DE_I[$name]" $name $_de_state[$name] "$value" "$hint"
  done

  if (( $#_de_issues )); then
    print
    _de_group
    _de_print_issues
  fi
}

# Kept from the old MySQL switcher: report who owns :3306
mysql-status() {
  _de_group
  local owner=$(_de_port_owner 3306)
  _de_row "$_DE_I[mysql]" mysql "$(_de_owned "$owner" "${owner%% *}")" "$(_de_q "$owner")" ':3306'
}

# ── main command ─────────────────────────────────────────────────────────────

devenv() {
  local target=$1 current=$(<"$DEVENV_STATE" 2>/dev/null)

  case $target in
    status|"") devenv-status "${@:2}"; return ;;
    toggle)    [[ $current == herd ]] && target=flock || target=herd ;;
    herd|flock) ;;
    doctor)    devenv-doctor "${@:2}"; return ;;
    *) print "usage: devenv [herd|flock|toggle|status|doctor]"; return 1 ;;
  esac

  if [[ $target == herd && ( ! -d $_DE_HERD_APP || ! -x $_DE_HERD_CLI ) ]]; then
    _de_err 'Install and open Laravel Herd before switching to it.'
    return 1
  elif [[ $target == flock && ( ! -d $_DE_FLOCK_APP || ! -x $_DE_FLOCK_CLI ) ]]; then
    _de_err 'Install and open Flock before switching to it.'
    return 1
  fi

  [[ -d $DEVENV_SITES ]] || _de_warn "$DEVENV_SITES isn't available — is the eSSD mounted?"

  _de_p "$_DE_I[switch]%BSwitching to ${(C)target}%b"
  if [[ $target == herd ]]; then
    _de_stop_flock || return 1
    _de_start_herd || return 1
  else
    _de_stop_herd  || return 1
    _de_start_flock || return 1
  fi

  mkdir -p "${DEVENV_STATE:h}"
  print -r -- "$target" >| "$DEVENV_STATE"
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

source "${${(%):-%x}:A:h}/tools.zsh"

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
