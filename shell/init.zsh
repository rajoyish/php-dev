# Source after the Herd and Flock PATH settings in .zshrc.
() {
  local repo_root=${${(%):-%x}:A:h:h}
  local repo_bin="$repo_root/bin" entry
  local -a remaining_path

  for entry in "${path[@]}"; do
    [[ ${entry%/} == "$repo_bin" ]] || remaining_path+=("$entry")
  done

  path=("$repo_bin" "${remaining_path[@]}")
  source "$repo_root/shell/devenv.zsh"
}
