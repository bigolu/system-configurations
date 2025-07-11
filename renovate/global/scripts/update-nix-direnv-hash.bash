#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter direnv

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# WARNING: The VS Code Bash debugger extension does not support BASH_REMATCH:
# https://github.com/rogalmic/vscode-bash-debug/issues/183

nix_direnv_url_pattern='https://raw.githubusercontent.com/nix-community/nix-direnv/.*/direnvrc'

function main {
  local -r envrc_path="$1"

  local nix_direnv_url
  nix_direnv_url="$(get_nix_direnv_url "$envrc_path")"

  local new_nix_direnv_hash
  new_nix_direnv_hash="$(direnv fetchurl "$nix_direnv_url")"

  replace_nix_direnv_hash "$envrc_path" "$new_nix_direnv_hash"
}

function get_nix_direnv_url {
  local -r envrc_path="$1"

  local -r original_envrc="$(<"$envrc_path")"
  local -r regex=".*(${nix_direnv_url_pattern}).*"
  if ! [[ $original_envrc =~ $regex ]]; then
    echo 'Error: Could not find the nix-direnv URL' >&2
    exit 1
  fi

  echo "${BASH_REMATCH[1]}"
}

function replace_nix_direnv_hash {
  local -r envrc_path="$1"
  local -r new_hash="$2"

  local original_envrc
  original_envrc="$(<"$envrc_path")"

  # \\\\\n matches a backslash followed by a newline. This allows you to continue a
  # statement on a newline in Bash
  local -r separator=$'( |\\\\\n)+'
  local -r quote=$'[\'"]'
  local -r nix_direnv_hash=$'[^\'"]+'
  local -r everything_before_nix_direnv_hash=".*source_url${separator}${quote}${nix_direnv_url_pattern}${quote}${separator}${quote}"
  local -r everything_after_nix_direnv_hash="${quote}.*"
  local -r replacement_regex="($everything_before_nix_direnv_hash)${nix_direnv_hash}($everything_after_nix_direnv_hash)"

  if ! [[ $original_envrc =~ $replacement_regex ]]; then
    echo 'Error: Could not find the nix-direnv hash' >&2
    exit 1
  fi
  local -r new_envrc="${BASH_REMATCH[1]}${new_hash}${BASH_REMATCH[4]}"

  echo "$new_envrc" >"$envrc_path"
}

main "$@"
