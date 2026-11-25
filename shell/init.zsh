# Source after the Herd and Flock PATH settings in .zshrc.
() {
  local root=${${(%):-%x}:A:h:h}
  local cli_bin=${1:-"$root/bin"} entry
  local -a remaining_path

  for entry in "${path[@]}"; do
    [[ ${entry%/} == "$cli_bin" ]] || remaining_path+=("$entry")
  done

  path=("$cli_bin" "${remaining_path[@]}")
  source "$root/shell/devenv.zsh"
} "${1:-}"
