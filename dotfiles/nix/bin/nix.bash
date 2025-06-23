#!/usr/bin/env bash

# Warn users that any untracked files will be ignored by any nix flake operations.
# Though nix may make this behavior configurable in the future[1][2].
#
# [1]: https://github.com/NixOS/nix/pull/6858
# [2]: https://github.com/NixOS/nix/issues/7107

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

yellow='\e[33m'
red='\e[31m'
reset='\e[0m'

function main {
  local -ra nix_args=("$@")

  local real_nix
  real_nix="$(get_real_command)"

  maybe_warn_about_untracked_files

  exec "$real_nix" "${nix_args[@]}"
}

function get_real_command {
  if [[ ${PORTABLE_HOME:-} == 'true' ]]; then
    # Since I wrap and exec my scripts in portable home, I won't find this program on
    # the PATH, it's wrapper will be, so just get the last one on the path.
    get_last_command_on_path
  else
    # To find the real command just take the next instance of this command on the
    # $PATH after this one. This way if there are other wrappers they can do the same
    # and eventually we'll reach the real one. Though this only works if this program
    # is on the PATH and not something else that calls this.
    get_next_command_on_path
  fi
}

function get_last_command_on_path {
  local -r program_basename="${0##*/}"

  local which_output
  which_output="$(which -a "$program_basename")"

  local -a command_entries
  readarray -t command_entries <<<"$which_output"

  if ((${#command_entries[@]} > 1)); then
    echo "${command_entries[-1]}"
  else
    abort
  fi
}

function get_next_command_on_path {
  local -r program_basename="${0##*/}"

  local which_output
  which_output="$(which -a "$program_basename")"

  local -a command_entries
  readarray -t command_entries <<<"$which_output"

  local this_command_index
  this_command_index="$(index_of "$0" "${command_entries[@]}")"
  if [[ -z $this_command_index ]]; then
    abort
  fi

  local next_command
  next_command="${command_entries[this_command_index + 1]}"
  if [[ -z $next_command ]]; then
    abort
  fi

  echo "$next_command"
}

function maybe_warn_about_untracked_files {
  # Search the current directory and its ancestors for a flake.nix file
  local current_directory="$PWD"
  local is_in_flake=false
  while true; do
    if [[ -f $current_directory/flake.nix ]]; then
      is_in_flake=true
      break
    fi

    local parent_directory="$current_directory/.."
    # This will happen when we hit the root directory '/'
    if [[ $current_directory -ef $parent_directory ]]; then
      break
    fi
    current_directory="$parent_directory"
  done
  if [[ $is_in_flake == false ]]; then
    return
  fi

  git ls-files -z --deleted --others --exclude-standard |
    {
      readarray -d '' untracked_or_deleted_files
      if ((${#untracked_or_deleted_files[@]} > 0)); then
        local joined_untracked_or_deleted_files
        joined_untracked_or_deleted_files="$(join ' ' "${untracked_or_deleted_files[@]}")"

        {
          echo -e "\n${yellow}┃ nix-wrapper: WARNING: Files outside the git index will be ignored by any flake operation.${reset}"
          echo 'You can add them to the index with the following command:'
          echo "git add --intent-to-add ${joined_untracked_or_deleted_files}"
        } >/dev/tty 2>&1
      fi
    }
}

function abort {
  if [[ -t 2 ]]; then
    echo -e "\n${red}┃ nix-wrapper: Unable to find the real nix${reset}" >&2
  fi
  exit 127
}

function index_of {
  local -r target="$1"
  local -ra list=("${@:2}")

  local index
  for index in "${!list[@]}"; do
    if [[ ${list[$index]} == "${target}" ]]; then
      echo "${index}"
      return
    fi
  done
}

# source: https://stackoverflow.com/a/17841619
function join {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

main "$@"
