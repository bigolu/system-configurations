#!/usr/bin/env bash

# This script is a multi-call program[1] that acts as a shim[2] for nix-build,
# nix-shell, and the new cli, nix. Its features vary based on what program it's
# executed as:
#
# nix-build, nix-shell, or nix:
#   - Use nom to display build outputs
# nix:
#   - Warn users that any untracked files will be ignored by any nix flake
#     operations. Though nix may make this behavior configurable in the future[3][4].
#
# [1]: https://www.redbooks.ibm.com/abstracts/tips0092.html
# [2]: https://stackoverflow.com/a/51646150
# [2]: https://github.com/NixOS/nix/pull/6858
# [3]: https://github.com/NixOS/nix/issues/7107

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

yellow='\e[33m'
red='\e[31m'
reset='\e[0m'

function main {
  local -ra nix_args=("$@")

  local -r program_basename="${0##*/}"

  local shim=''
  case "$program_basename" in
    'nix-build')
      shim='nix_build_shim'
      ;;
    'nix-shell')
      shim='nix_shell_shim'
      ;;
    'nix')
      shim='nix_shim'
      ;;
  esac
  "$shim" "${nix_args[@]}"
}

function nix_build_shim {
  local -ra nix_args=("$@")

  local real_nix_build
  real_nix_build="$(get_real_command)"

  exec {stdout_copy}>&1
  exec "$real_nix_build" --log-format internal-json -v "${nix_args[@]}" 2>&1 1>&$stdout_copy | nom --json
}

function nix_shell_shim {
  local -ra nix_args=("$@")

  local real_nix_shell
  real_nix_shell="$(get_real_command)"

  exec {stdout_copy}>&1
  exec "$real_nix_shell" --log-format internal-json -v "${nix_args[@]}" 2>&1 1>&$stdout_copy | nom --json
}

function nix_shim {
  local -ra nix_args=("$@")

  local real_nix
  real_nix="$(get_real_command)"

  if
    is_set 'NIX_GET_COMPLETIONS' \
      || contains 'run' "${nix_args[@]}" \
      || contains 'shell' "${nix_args[@]}" \
      || contains 'develop' "${nix_args[@]}" \
      || contains '-c' "${nix_args[@]}" \
      || contains '--command' "${nix_args[@]}"
  then
    exec "$real_nix" "${nix_args[@]}"
  fi

  maybe_warn_about_untracked_files

  # This won't be necessary if nom adds support for passing non-build commands to the
  # real nix[1].
  #
  # [1]: https://github.com/maralorn/nix-output-monitor/issues/109
  if can_trigger_build "${nix_args[@]}"; then
    exec {stdout_copy}>&1
    exec "$real_nix" --log-format internal-json -v "${nix_args[@]}" 2>&1 1>&$stdout_copy | nom --json
  else
    exec "$real_nix" "${nix_args[@]}"
  fi
}

function can_trigger_build {
  local -ra nix_args=("$@")
  local -ra subcommands_that_trigger_builds=(build shell develop print-dev-env bundle run)

  local arg
  for arg in "${nix_args[@]}"; do
    if contains "$arg" "${subcommands_that_trigger_builds[@]}"; then
      return 0
    fi
  done

  return 1
}

function get_real_command {
  if [[ -n ${BIGOLU_IN_PORTABLE_HOME+set} ]]; then
    # Since I wrap and exec my scripts in portable home, I won't find this program on
    # the PATH, it's wrapper will be, so just get the last one on the path.
    get_last_command_on_path
  else
    # To find the real command just take the next instance of this command on the
    # $PATH after this one. This way if there are other wrappers they can do the same
    # and eventually we'll reach the real one.
    get_next_command_on_path
  fi
}

function get_last_command_on_path {
  local -r program_basename="${0##*/}"

  local -a command_entries
  readarray -t command_entries < <(which -a "$program_basename")

  if ((${#command_entries[@]} > 1)); then
    echo "${command_entries[-1]}"
  else
    abort
  fi
}

function get_next_command_on_path {
  local -r program_basename="${0##*/}"

  local -a command_entries
  readarray -t command_entries < <(which -a "$program_basename")

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
  if ! is_in_flake; then
    return
  fi

  local -a untracked_or_deleted_files
  readarray -d '' untracked_or_deleted_files \
    < <(git ls-files -z --deleted --others --exclude-standard)

  if ((${#untracked_or_deleted_files[@]} > 0)); then
    local -r joined_untracked_or_deleted_files="$(join ' ' "${untracked_or_deleted_files[@]}")"

    {
      echo -e "\n${yellow}┃ nix-wrapper: WARNING: Files outside the git index will be ignored by any flake operation.${reset}"
      echo 'You can add them to the index with the following command:'
      echo "git add --intent-to-add ${joined_untracked_or_deleted_files})"
    } >/dev/tty 2>&1
  fi
}

function is_in_flake {
  # Search the current directory and its ancestors for a flake.nix file
  local current_directory="$PWD"
  while true; do
    if [[ -f $current_directory/flake.nix ]]; then
      return 0
    fi

    local parent_directory="$current_directory/.."
    # This will happen when we hit the root directory '/'
    if [[ $current_directory -ef $parent_directory ]]; then
      break
    fi
    current_directory="$parent_directory"
  done

  return 1
}

function abort {
  if [[ -t 2 ]]; then
    echo -e "\n${red}┃ nix-wrapper: Unable to find the real nix${reset}" >&2
  fi
  exit 127
}

function contains {
  local -r target="$1"
  local -ra list=("${@:2}")

  [[ -n $(index_of "$target" "${list[@]}") ]]
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

function is_set {
  local -r variable_name="$1"
  [[ -n ${!variable_name+x} ]]
}

main "$@"
