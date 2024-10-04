#!/usr/bin/env bash

# If the user is in a git repository with untracked files, warn them since those
# files will be ignored by any Nix Flake operation.
#
# TODO: They're considering making this behaviour configurable though. In which case I can remove this.
# issue: https://github.com/NixOS/nix/pull/6858
# issue: https://github.com/NixOS/nix/issues/7107

set -o errexit
set -o nounset
set -o pipefail

function main {
  # To find the real nix just take the next nix binary on the $PATH after
  # this one. This way if there are other wrappers they can do the same and
  # eventually we'll reach the real nix.
  readarray -t nix_commands < <(which -a nix)
  this_nix_index="$(index_of "$0" "${nix_commands[@]}")"
  if [[ -z "$this_nix_index" ]]; then
    abort
  fi
  real_nix="${nix_commands[(($this_nix_index + 1))]}"
  if [[ -z "$real_nix" ]]; then
    abort
  fi

  maybe_warn
  exec "$real_nix" "$@"
}

function maybe_warn {
  # Search the current directory and its ancestors for a flake.nix file
  found_flake=
  current_directory="$PWD"
  while true; do
    if [[ -f "$current_directory/flake.nix" ]]; then
      found_flake=1
      break
    fi

    parent_directory="$current_directory/.."
    # This will happen when hit the root directory '/'
    if [[ "$current_directory" -ef "$parent_directory" ]]; then
      break
    fi
    current_directory="$parent_directory"
  done

  if [[ -z "$found_flake" ]]; then
    return
  fi

  readarray -d '' untracked_or_deleted_files < <(git ls-files -z --deleted --others --exclude-standard)

  if ((${#untracked_or_deleted_files[@]} > 0)); then
    {
      printf "\n\e[33m┃ nix: WARNING: Files outside the git index will be ignored by any flake operation.\e(B\e[m\n"
      echo 'You can add them to the index with the following command:'
      printf 'git add --intent-to-add %s\n' "$(printf '%s ' "${untracked_or_deleted_files[@]}")"
    } >/dev/tty 2>&1
  fi
}

function abort {
  if [[ -t 2 ]]; then
    echo -e '\e[31mError: Unable to find the real nix' >&2
  fi
  exit 127
}

function index_of {
  target="$1"
  shift
  list=("$@")
  for i in "${!list[@]}"; do
    if [[ "${list[$i]}" = "${target}" ]]; then
      echo "${i}"
      return
    fi
  done
}

main "$@"
