# ─────────────────────────────────────────────────────────────────────────────
# php-dev tools: doctor, sites, open, logs and db. Sourced by devenv.zsh.
# ─────────────────────────────────────────────────────────────────────────────

typeset -g _DE_ROOT=${${(%):-%x}:A:h:h}
typeset -g _DE_HERD_LOGS="$HOME/Library/Application Support/Herd/Log"

# ── doctor ───────────────────────────────────────────────────────────────────

# _de_check <state> <label> [detail]
_de_check() {
  local detail=
  [[ -n $3 ]] && detail="  %F{8}$(_de_q "$3")%f"
  _de_p "  $(_de_dot $1)$2$detail"
}

_de_zshrc() {
  local f=${ZDOTDIR:-$HOME}/.zshrc
  [[ -L $f ]] && f=${f:A}
  print -r -- "$f"
}

# Report tools, setup and stack health. With --fix, repair what can be repaired.
devenv-doctor() {
  local fix=0
  case $1 in
    --fix) fix=1 ;;
    '') ;;
    *) _de_err "usage: php-dev doctor [--fix]"; return 2 ;;
  esac

  _de_p "$_DE_I[doctor]%Bphp-dev doctor%b"
  print
  _de_p "$_DE_I[apps]%BApps%b"
  if [[ -d $_DE_HERD_APP && -x $_DE_HERD_CLI ]]; then _de_check ok 'Laravel Herd' "$_DE_HERD_APP"
  else _de_check off 'Laravel Herd is not installed' 'needed only for the Herd stack'; fi
  if [[ -d $_DE_FLOCK_APP && -x $_DE_FLOCK_CLI ]]; then _de_check ok 'Flock' "$_DE_FLOCK_APP"
  else _de_check off 'Flock is not installed' 'needed only for the Flock stack'; fi
  local plist=$(_de_dbngin_plist)
  if [[ -n $plist ]]; then _de_check ok 'DBngin MySQL' "$plist"
  else _de_check off 'No DBngin MySQL instance' 'create one in DBngin for the Herd stack'; fi
  local client=$(_de_mysql_client)
  if [[ -n $client ]]; then _de_check ok 'MySQL client' "$client"
  else _de_check warn 'No MySQL client found' 'php-dev db needs one'; fi

  print
  _de_p "$_DE_I[setup]%BSetup%b"
  local zshrc=$(_de_zshrc) setup_issues=0
  if grep -qF '# >>> php-dev >>>' "$zshrc" 2>/dev/null; then _de_check ok 'Zsh is configured' "$zshrc"
  else _de_check warn 'Zsh is not configured' 'run: php-dev install'; (( setup_issues++ )); fi
  if [[ -r $_DE_ROOT/vendor/autoload.php ]]; then _de_check ok 'Menu dependencies are installed'
  else _de_check bad 'Menu dependencies are missing' "run: composer install in $_DE_ROOT"; (( setup_issues++ )); fi
  case $(<"$DEVENV_STATE" 2>/dev/null) in
    herd|flock) _de_check ok 'Saved stack' "$DEVENV_STATE" ;;
    *) _de_check bad 'No valid saved stack' 'run: php-dev herd or php-dev flock'; (( setup_issues++ )) ;;
  esac
  local owner=$(_de_port_owner 443)
  if [[ $owner == free ]]; then _de_check warn 'Nothing is serving HTTPS on :443'
  else _de_check $(_de_owned "$owner" "${(C)$(<"$DEVENV_STATE" 2>/dev/null)}") "HTTPS :443" "$owner"; fi

  print
  _de_p "$_DE_I[stack]%BStack%b"
  _de_collect
  local name
  for name in $_de_checks; do
    [[ $_de_state[$name] == ok ]] && _de_check ok "$_DE_I[$name]$name" "$_de_value[$name]"
  done
  _de_print_issues

  print
  if (( ! $#_de_issues && ! setup_issues )); then
    _de_ok "Everything looks good"
    return 0
  fi
  if (( ! fix )); then
    (( $#_de_issues )) && _de_p "Run %Bphp-dev doctor --fix%b to repair the stack."
    return 1
  fi
  _de_repair
}

# Run the fixes _de_collect found. A full stack switch covers everything else.
_de_repair() {
  local -a fixes=(${(u)_de_fixes:#})
  if (( ! $#fixes )); then
    _de_warn "Nothing here can be fixed automatically."
    return 1
  fi
  if (( ${fixes[(I)herd]} || ${fixes[(I)flock]} )); then
    devenv $_de_active
  else
    (( ${fixes[(I)mysql *]} )) && switch-mysql ${${fixes[(r)mysql *]}#mysql }
    (( ${fixes[(I)path]} )) && { _devenv_apply_path "$_de_active"; _de_ok "PATH now uses ${(C)_de_active}"; }
  fi
}

# ── sites ────────────────────────────────────────────────────────────────────

# Site name for a directory under $DEVENV_SITES (empty when it isn't in one)
_de_site_for() {
  local dir=${1:A} root=${DEVENV_SITES:A}
  [[ $dir == $root/* ]] || return 1
  local rel=${dir#$root/}
  print -r -- ${(L)rel%%/*}
}

_de_site_icon() {
  if   [[ -f $1/artisan ]];       then print -rn -- "$_DE_I[laravel]"
  elif [[ -f $1/composer.json ]]; then print -rn -- "$_DE_I[package]"
  elif [[ -f $1/package.json ]];  then print -rn -- "$_DE_I[node]"
  else                                 print -rn -- "$_DE_I[dir]"
  fi
}

devenv-sites() {
  if [[ ! -d $DEVENV_SITES ]]; then
    _de_err "$DEVENV_SITES isn't available."
    return 1
  fi
  local here=$(_de_site_for $PWD) dir name mark
  local -a dirs=("$DEVENV_SITES"/*(/N))
  _de_p "$_DE_I[folder]%BSites in $(_de_q "$DEVENV_SITES")%b  %F{8}($#dirs)%f"
  for dir in $dirs; do
    name=${(L)dir:t}
    [[ $name == $here ]] && mark='  %F{green}← here%f' || mark=
    _de_p "  $(_de_site_icon $dir)${(r:28:)name} %F{cyan}$(_de_q "http://$name.test")%f$mark"
  done
  _de_p "  $_DE_I[laravel]%F{8}Laravel%f  $_DE_I[package]%F{8}PHP%f  $_DE_I[node]%F{8}Node%f  $_DE_I[dir]%F{8}other%f"
}

# ── open ─────────────────────────────────────────────────────────────────────

_de_site_url() {
  local host="$1.test"
  if curl -sk -o /dev/null -m 2 "https://$host" 2>/dev/null; then print -r -- "https://$host"
  else print -r -- "http://$host"; fi
}

devenv-open() {
  local name=${1:-$(_de_site_for $PWD)}
  if [[ -z $name ]]; then
    _de_err "Run this inside $DEVENV_SITES or name a site: php-dev open <site>"
    return 1
  fi
  local url=$(_de_site_url ${(L)name})
  _de_p "$_DE_I[open]Opening $(_de_q "$url")"
  open "$url"
}

# ── logs ─────────────────────────────────────────────────────────────────────

# Names of the logs the active stack has
_de_log_names() {
  local -a files
  case $(<"$DEVENV_STATE" 2>/dev/null) in
    flock) files=("$_DE_FLOCK_HOME"/log/*.log(N)) ;;
    herd)  files=("$_DE_HERD_LOGS"/*.log(N)) ;;
  esac
  print -rl -- ${files:t:r}
}

# devenv-logs [name] [-f] [-n lines]
devenv-logs() {
  local name follow=0 lines=50
  while (( $# )); do
    case $1 in
      -f|--follow) follow=1 ;;
      -n|--lines)  lines=$2; shift ;;
      -*) _de_err "usage: php-dev logs [name] [-f] [-n lines]"; return 2 ;;
      *)  name=$1 ;;
    esac
    shift
  done

  local -a names=($(_de_log_names))
  if [[ -z $name ]]; then
    _de_p "$_DE_I[logs]%BLogs for ${(C)$(<"$DEVENV_STATE" 2>/dev/null)}%b"
    print -rl -- "  "${^names}
    _de_p "%F{8}Show one with: php-dev logs <name> [-f]%f"
    return
  fi
  if (( ! ${names[(Ie)$name]} )); then
    _de_err "No log named '$name'. Available: ${(j:, :)names}"
    return 1
  fi

  case $(<"$DEVENV_STATE" 2>/dev/null) in
    flock) "$_DE_FLOCK_CLI" logs "$name" -n "$lines" ${${follow:#0}:+-f} ;;
    herd)  tail -n "$lines" ${${follow:#0}:+-f} "$_DE_HERD_LOGS/$name.log" ;;
  esac
}

# ── db ───────────────────────────────────────────────────────────────────────

_de_mysql_client() {
  local c=$(whence -p mysql)
  [[ -z $c ]] && c=${${(On)$(print -l "$_DE_FLOCK_HOME"/services/mysql/*/bin/mysql(N*))}[1]}
  [[ -z $c ]] && c=${${(On)$(print -l /Users/Shared/DBngin/mysql/*/bin/mysql(N*))}[1]}
  print -r -- "$c"
}

# Value of KEY in a .env file, without surrounding quotes
_de_env_value() {
  local line
  for line in ${(f)"$(<$1)"}; do
    [[ $line == $2=* ]] || continue
    line=${line#$2=}
    line=${line%%[[:space:]]\#*}
    print -r -- "${${line#[\"\']}%[\"\']}"
    return
  done
}

# Open a MySQL shell on :3306, using the Laravel project's .env when it has MySQL settings.
devenv-db() {
  local client=$(_de_mysql_client)
  if [[ -z $client ]]; then
    _de_err "No MySQL client found. Install one with: brew install mysql-client"
    return 1
  fi

  local host=127.0.0.1 port=3306 user=root pass= db=$1
  if [[ -f .env && $(_de_env_value .env DB_CONNECTION) == (mysql|mariadb) ]]; then
    host=${$(_de_env_value .env DB_HOST):-$host}
    port=${$(_de_env_value .env DB_PORT):-$port}
    user=${$(_de_env_value .env DB_USERNAME):-$user}
    pass=$(_de_env_value .env DB_PASSWORD)
    db=${db:-$(_de_env_value .env DB_DATABASE)}
  fi
  [[ $host == localhost ]] && host=127.0.0.1

  _de_p "$_DE_I[db]$(_de_q "$user@$host:$port${db:+/$db}")  %F{8}$(_de_q "$(_de_port_owner $port)")%f"
  MYSQL_PWD=$pass "$client" -h "$host" -P "$port" -u "$user" ${db:+"$db"}
}
