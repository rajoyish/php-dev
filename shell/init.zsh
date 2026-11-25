# Source after the Herd and Flock PATH settings in .zshrc.
() {
  local root=${${(%):-%x}:A:h:h}
  local cli_bin=${1:-"$root/bin"} entry
  local -a remaining_path

  for entry in "${path[@]}"; do
    [[ ${entry%/} == "$cli_bin" ]] || remaining_path+=("$entry")
  done

  path=("$cli_bin" "${remaining_path[@]}")

  # Tab completion: picked up by a later compinit, or registered now if compinit already ran.
  fpath=("$root/shell/completions" "${fpath[@]}")
  if (( $+functions[compdef] )); then
    autoload -Uz _php-dev
    compdef _php-dev php-dev phpd
  fi

  source "$root/shell/devenv.zsh"
} "${1:-}"
