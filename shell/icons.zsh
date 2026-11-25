# ─────────────────────────────────────────────────────────────────────────────
# Icon sets. emoji works in any terminal; nerd needs a Nerd Font.
# nerd is the default. Pick one with PHP_DEV_ICONS=emoji|nerd, or save it
# with: php-dev icons emoji
#
# Emoji are two columns wide and Nerd Font glyphs one, so the glyphs carry a
# trailing space; _de_load_icons then pads both to three columns, ready to put
# directly before text. Values are print -P strings: show them with _de_p.
# ─────────────────────────────────────────────────────────────────────────────

typeset -gA _DE_ICONS_EMOJI=(
  web 🌐  mail 📬  mysql 🐬  dns 🧭  php 🐘  composer 🎼  sites 📁
  laravel 🐘  package 📦  node 🟩  dir 📁  folder 📂
  ok ✅  warn 🟡  err ❌  wait ⏳
  dot_ok 🟢  dot_warn 🟡  dot_bad 🔴  dot_off ⚪
  switch 🔀  doctor 🩺  apps 🧰  setup 🔧  stack 🔌  open 🌍  logs 📜  db 💾  palette 🎨
)

# Font Awesome, Devicons and Material Design glyphs from Nerd Fonts v3
typeset -gA _DE_ICONS_NERD=(
  web      $' '              # fa-globe
  mail     $' '              # fa-envelope
  mysql    $'%F{cyan}%f '    # dev-mysql
  dns      $' '              # fa-compass
  php      $'%F{blue}󰟆%f '    # md-elephant
  composer $' '              # fa-cubes
  sites    $' '              # fa-folder
  laravel  $'%F{red}%f '     # dev-laravel
  package  $'%F{blue}󰟆%f '    # md-elephant
  node     $'%F{green}%f '   # dev-nodejs_small
  dir      $' '              # fa-folder
  folder   $' '              # fa-folder_open
  ok       $'%F{green}%f '   # fa-check
  warn     $'%F{yellow}%f '  # fa-exclamation_triangle
  err      $'%F{red}%f '     # fa-times
  wait     $'%F{cyan}%f '    # fa-hourglass_half
  dot_ok   $'%F{green}%f '   # fa-check_circle
  dot_warn $'%F{yellow}%f '  # fa-exclamation_circle
  dot_bad  $'%F{red}%f '     # fa-times_circle
  dot_off  $'%F{8}%f '       # fa-circle_o
  switch   $' '              # fa-exchange
  doctor   $'%F{red}%f '     # fa-stethoscope
  apps     $' '              # fa-briefcase
  setup    $' '              # fa-wrench
  stack    $' '              # fa-plug
  open     $' '              # fa-external_link
  logs     $' '              # fa-file_text
  db       $' '              # fa-database
  palette  $' '              # fa-paint_brush
)

# The icon style: $PHP_DEV_ICONS, else the saved choice, else nerd.
_de_icon_style() {
  local style=$PHP_DEV_ICONS file="${DEVENV_STATE:h}/icons"
  [[ -z $style && -r $file ]] && style=$(<"$file")
  [[ $style == emoji ]] && print emoji || print nerd
}

_de_load_icons() {
  typeset -g _DE_ICON_STYLE=$(_de_icon_style)
  typeset -gA _DE_I
  if [[ $_DE_ICON_STYLE == nerd ]]; then _DE_I=("${(@kv)_DE_ICONS_NERD}")
  else                                   _DE_I=("${(@kv)_DE_ICONS_EMOJI}"); fi
  # Pad every icon to three columns: emoji + 1 space, or glyph + 2 spaces.
  local k
  for k in ${(k)_DE_I}; do _DE_I[$k]+=' '; done
}

# php-dev icons [emoji|nerd]: show or save the icon style
devenv-icons() {
  local file="${DEVENV_STATE:h}/icons"
  case $1 in
    '')
      local from=
      [[ -n $PHP_DEV_ICONS ]] && from='  %F{8}(from PHP_DEV_ICONS)%f'
      _de_p "$_DE_I[palette]Icon style: %B$_DE_ICON_STYLE%b$from"
      print
      local style name line
      local -A set
      for style in emoji nerd; do
        if [[ $style == nerd ]]; then set=("${(@kv)_DE_ICONS_NERD}"); else set=("${(@kv)_DE_ICONS_EMOJI}"); fi
        line=
        for name in php laravel mysql web mail dns composer dot_ok dot_warn dot_bad; do line+="$set[$name] "; done
        _de_p "  ${(r:6:)style} $line"
      done
      print
      _de_p "%F{8}Change it with: php-dev icons nerd|emoji  (nerd needs a Nerd Font)%f"
      ;;
    emoji|nerd)
      mkdir -p "${file:h}"
      print -r -- $1 >| "$file"
      _de_load_icons
      [[ -n $PHP_DEV_ICONS && $PHP_DEV_ICONS != $1 ]] \
        && _de_warn "PHP_DEV_ICONS=$PHP_DEV_ICONS is set and overrides this choice"
      _de_ok "Saved the $1 icon style"
      ;;
    *) _de_err "usage: php-dev icons [emoji|nerd]"; return 2 ;;
  esac
}

_de_load_icons
