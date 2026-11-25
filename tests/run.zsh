#!/bin/zsh -f
# Tests for php-dev. Port owners, apps and paths are faked, so this runs anywhere.
# Usage: zsh tests/run.zsh

root=${0:A:h:h}
tmp=$(mktemp -d)
trap 'rm -rf $tmp' EXIT
passed=0 failed=0

pass() { (( passed++ )); print -r -- "✅ $1"; }
fail() { (( failed++ )); print -r -- "❌ $1"; [[ -n $2 ]] && print -r -- "$2" | sed 's/^/     /'; }

# expect <name> <haystack> <needle>
expect() { [[ $2 == *$3* ]] && pass "$1" || fail "$1" "expected to find: $3"$'\n'"in: $2"; }
refute() { [[ $2 != *$3* ]] && pass "$1" || fail "$1" "did not expect: $3"$'\n'"in: $2"; }

# A sandbox shell with devenv loaded and ports faked.
# sandbox <stack> <web owner> <mysql owner> <resolver: flock|herd|none> -- <zsh code>
sandbox() {
  local stack=$1 web=$2 mysql=$3 dns=$4; shift 5
  mkdir -p $tmp/bin/flock $tmp/bin/herd $tmp/sites/blog $tmp/sites/Shop
  touch $tmp/sites/blog/artisan $tmp/sites/Shop/composer.json
  for f in php composer; do
    print '#!/bin/sh\necho 8.4.0' > $tmp/bin/$stack/$f 2>/dev/null; chmod +x $tmp/bin/$stack/$f 2>/dev/null
  done
  case $dns in
    flock) print 'nameserver 127.0.0.1\nport 53535' > $tmp/resolver ;;
    herd)  print 'nameserver 127.0.0.1' > $tmp/resolver ;;
    none)  rm -f $tmp/resolver ;;
  esac
  print -r -- $stack > $tmp/active
  DEVENV_STATE=$tmp/active DEVENV_SITES=$tmp/sites HOME=$tmp NO_COLOR=1 zsh -fc "
    source '$root/shell/devenv.zsh'
    _DE_RESOLVER='$tmp/resolver'
    _DE_FLOCK_BIN='$tmp/bin/flock' _DE_HERD_BIN='$tmp/bin/herd'
    path=('$tmp/bin/$stack' /usr/bin /bin); rehash
    _de_port_owner() {
      case \$1 in
        80|2525) print -r -- '$web' ;;
        3306)    print -r -- '$mysql' ;;
        *)       print free ;;
      esac
    }
    $*
  " 2>&1
}

# ── status ──
out=$(PHP_DEV_ICONS=emoji sandbox flock 'Flock (pid 1)' 'Flock (pid 2)' flock -- devenv-status)
expect 'status shows the active stack' "$out" 'Active stack: Flock'
expect 'status shows the PHP icon and version' "$out" '🐘 php       🟢 8.4.0'
refute 'healthy status lists no issues' "$out" '→'

out=$(sandbox herd 'Flock (pid 1)' 'Flock (pid 2)' flock -- devenv-status)
expect 'web mismatch is flagged' "$out" "Port :80 isn't served by Herd"
expect 'web mismatch suggests a switch' "$out" '→ php-dev herd'
expect 'MySQL mismatch suggests DBngin' "$out" '→ php-dev mysql dbngin'
expect 'DNS mismatch is flagged' "$out" '.test DNS points at Flock'

out=$(sandbox flock 'Flock (pid 1)' free none -- devenv-status)
expect 'free MySQL is flagged' "$out" "MySQL on :3306 isn't Flock (free)"
expect 'missing resolver is flagged' "$out" '.test DNS points at none'

# ── json ──
json=$(sandbox herd 'Flock (pid 1)' 'DBngin (pid 2)' herd -- devenv-status --json)
php -r '
  $s = json_decode($argv[1], true, flags: JSON_THROW_ON_ERROR);
  exit($s["stack"] === "herd" && $s["healthy"] === false && $s["checks"]["mysql"]["state"] === "ok"
    && count($s["issues"]) === 1 && $s["issues"][0]["fix"] === "php-dev herd" ? 0 : 1);
' "$json" && pass 'status --json is valid and accurate' || fail 'status --json is valid and accurate' "$json"

# ── doctor ──
out=$(PHP_DEV_ICONS=emoji sandbox herd 'Herd (pid 1)' 'DBngin (pid 2)' herd -- 'devenv-doctor; print exit=$?')
expect 'doctor reports app checks' "$out" '🧰 Apps'
expect 'doctor fails without a Zsh setup' "$out" 'Zsh is not configured'
expect 'doctor exits non-zero on problems' "$out" 'exit=1'
out=$(sandbox herd 'Herd (pid 1)' 'DBngin (pid 2)' herd -- 'devenv-doctor --nope; print exit=$?')
expect 'doctor rejects unknown options' "$out" 'exit=2'

# ── sites / open / db ──
out=$(PHP_DEV_ICONS=emoji sandbox flock 'Flock (pid 1)' 'Flock (pid 2)' flock -- "cd '$tmp/sites/blog'; devenv-sites")
expect 'sites marks Laravel projects' "$out" '🐘 blog'
expect 'sites lowercases site names' "$out" 'http://shop.test'
expect 'sites marks the current site' "$out" '← here'
out=$(sandbox flock 'Flock (pid 1)' 'Flock (pid 2)' flock -- "cd '$tmp/sites/blog/'; _de_site_for \$PWD")
expect 'the current site comes from the directory' "$out" 'blog'
out=$(sandbox flock 'Flock (pid 1)' 'Flock (pid 2)' flock -- "cd '$tmp'; devenv-open; print exit=\$?")
expect 'open needs a site outside $DEVENV_SITES' "$out" 'exit=1'

print -r -- $'DB_CONNECTION=mysql\nDB_DATABASE="shop" # main\nDB_PASSWORD=\x27s3cret\x27' > $tmp/.env
out=$(sandbox flock x x flock -- "cd '$tmp'; _de_env_value .env DB_DATABASE; _de_env_value .env DB_PASSWORD; _de_env_value .env MISSING")
expect '.env values lose quotes and comments' "$out" $'shop\ns3cret'

# ── icons ──
out=$(PHP_DEV_ICONS=nerd sandbox flock 'Flock (pid 1)' 'Flock (pid 2)' flock -- devenv-status)
expect 'PHP_DEV_ICONS=nerd uses the elephant PHP glyph' "$out" $'\U000f07c6  php'
refute 'nerd style prints no emoji' "$out" '🐘'
out=$(sandbox flock 'Flock (pid 1)' 'Flock (pid 2)' flock -- 'devenv-icons nerd; devenv-status')
expect 'php-dev icons nerd saves the style' "$(<$tmp/icons)" 'nerd'
expect 'the saved style applies right away' "$out" $'\U000f07c6  php'
out=$(PHP_DEV_ICONS=emoji sandbox flock 'Flock (pid 1)' 'Flock (pid 2)' flock -- devenv-status)
expect 'PHP_DEV_ICONS overrides the saved style' "$out" '🐘 php'
rm -f $tmp/icons
out=$(sandbox flock 'Flock (pid 1)' 'Flock (pid 2)' flock -- devenv-status)
expect 'nerd is the default icon style' "$out" $'\U000f07c6  php'
out=$(sandbox flock x x flock -- 'devenv-icons emoji; devenv-status')
expect 'php-dev icons emoji switches back' "$out" '🐘 php'
rm -f $tmp/icons
out=$(sandbox flock x x flock -- 'devenv-icons wide; print exit=$?')
expect 'icons rejects unknown styles' "$out" 'exit=2'
php -r '
  require $argv[1];
  foreach (["emoji", "nerd"] as $style) {
      foreach (["php", "mysql", "settings", "back", "exit", "dot_ok"] as $name) {
          if (mb_strwidth(Icons::get($name, $style)) !== 3) exit(1);
      }
  }
' $root/src/icons.php && pass 'menu icons are three columns in both styles' || fail 'menu icons are three columns in both styles'

# ── CLI ──
out=$($root/bin/php-dev --help)
expect 'help lists doctor' "$out" 'doctor [--fix]'
[[ $($root/bin/phpd --help) == $out ]] && pass 'phpd is an alias for php-dev' || fail 'phpd is an alias for php-dev'
$root/bin/php-dev nope >/dev/null 2>&1; (( $? == 2 )) && pass 'unknown commands exit 2' || fail 'unknown commands exit 2'
$root/bin/php-dev status --nope >/dev/null 2>&1; (( $? == 2 )) && pass 'status rejects unknown options' || fail 'status rejects unknown options'
$root/bin/php-dev mysql nope >/dev/null 2>&1; (( $? == 2 )) && pass 'mysql rejects unknown actions' || fail 'mysql rejects unknown actions'

# ── syntax ──
for f in $root/bin/php-dev $root/shell/*.zsh $root/shell/completions/_php-dev; do
  zsh -n $f && pass "zsh syntax: ${f#$root/}" || fail "zsh syntax: ${f#$root/}"
done
for f in $root/src/*.php; do
  php -l $f >/dev/null && pass "php syntax: ${f#$root/}" || fail "php syntax: ${f#$root/}"
done

print
print -r -- "$passed passed, $failed failed"
(( failed == 0 ))
