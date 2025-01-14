#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter direnv ripgrep]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

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
  if ! rg \
    --no-config \
    --replace '$url' \
    ".*(?P<url>$nix_direnv_url_pattern).*" \
    "$envrc_path"; then
    echo 'Error: Could not find the nix-direnv URL' >&2
    exit 1
  fi
}

function replace_nix_direnv_hash {
  local -r envrc_path="$1"
  local -r new_hash="$2"

  # \\\n matches a backslash followed by a newline, which allows you to continue a
  # statement on a newline in Bash
  separator='( |\\\n)+'
  quote=$'[\'"]'
  local new_envrc
  if ! new_envrc="$(
    rg \
      --no-config \
      --multiline \
      --multiline-dotall \
      --replace "\${before_direnv_hash}${new_hash}\${after_direnv_hash}" \
      "(?P<before_direnv_hash>.*source_url${separator}${quote}${nix_direnv_url_pattern}${quote}${separator}${quote})(?P<nix_direnv_hash>[^'\"]+)(?P<after_direnv_hash>${quote}.*)" \
      "$envrc_path"
  )"; then
    echo 'Error: Could not find the nix-direnv hash' >&2
    exit 1
  fi

  echo "$new_envrc" >"$envrc_path"
}

main "$@"
