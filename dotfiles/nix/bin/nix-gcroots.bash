#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

function main {
  gcroots_directory='/nix/var/nix/gcroots'

  # automatic roots
  automatic_roots_directory="$gcroots_directory/auto"
  printf '\e[1m\e[4mAutomatic roots (%s):\e(B\e[m\n' "$automatic_roots_directory"
  print_roots_for_directory "$automatic_roots_directory"

  # per-user roots
  per_user_roots_directory="$gcroots_directory/per-user"
  # If the glob doesn't match anything, don't iterate at all, instead of
  # iterating one with the pattern.
  shopt -s nullglob
  for user_roots_directory in "$per_user_roots_directory"/*; do
    user="$(basename "$user_roots_directory")"
    printf '\e[1m\e[4mRoots for user "%s" (%s):\e(B\e[m\n' "$user" "$user_roots_directory"
    print_roots_for_directory "$user_roots_directory"
  done
  shopt -u nullglob

  # User profile roots
  per_user_profile_roots_directory="$gcroots_directory/profiles/per-user"
  # If the glob doesn't match anything, don't iterate at all, instead of
  # iterating one with the pattern.
  shopt -s nullglob
  for user_profile_roots_directory in "$per_user_profile_roots_directory"/*; do
    user="$(basename "$user_profile_roots_directory")"
    printf '\e[1m\e[4mRoots for user profile "%s" (%s):\e(B\e[m\n' "$user" "$user_profile_roots_directory"
    print_roots_for_directory "$user_profile_roots_directory"
  done
  shopt -u nullglob
}

function get_symlink_chain {
  symlink="$1"
  readarray -t chase_output < <(chase --verbose "$symlink" 2>/dev/null)
  # Remove the first line since it's the same as $symlink
  chase_output=("${chase_output[@]:1}")
  # Remove the last line since it's essentially a duplicate of the line before
  # it, the terminal file
  chase_output=("${chase_output[@]::((${#chase_output[@]} - 1))}")

  # The lines have the form '-> <path>' so I'm removing the first 3 characters to get the <path>.
  readarray -t chase_output_only_filenames < <(printf '%s\n' "${chase_output[@]}" | cut -c 4-)

  chase_output_only_filenames[0]='\e[34m'"${chase_output_only_filenames[0]}"'\e(B\e[m'

  joined_chain="$(join ' -> ' "${chase_output_only_filenames[@]}")"

  if [ -n "${NIX_GCROOTS_INCLUDE_SIZE:-}" ]; then
    # The out put of `du` looks like '<size> <filename>' so we're taking the
    # first group after splitting by a space.
    size="$(du --apparent-size -shL "$symlink" 2>/dev/null | cut -d' ' -f 1)"
    joined_chain="$size $joined_chain"
  fi

  echo "$joined_chain"
}

function print_roots_for_directory {
  directory="$1"
  potential_roots=("$directory"/*)
  # Filter out broken links
  roots=()
  for root in "${potential_roots[@]}"; do
    if [[ -e "$root" ]]; then
      roots=("${roots[@]}" "$root")
    fi
  done
  if ((${#roots[@]} == 0)); then
    echo "No roots found."
  else
    chains=()
    for root in "${roots[@]}"; do
      chains=("${chains[@]}" "$(get_symlink_chain "$root")")
    done
    if [ -n "${NIX_GCROOTS_INCLUDE_SIZE:-}" ]; then
      # sort by size, descending
      readarray -t chains < <(printf '%s\n' "${chains[@]}" | sort --human-numeric-sort --reverse)
    else
      # sort alphabetically, ascending
      readarray -t chains < <(printf '%s\n' "${chains[@]}" | sort)
    fi
    echo -e "$(printf '%s\n' "${chains[@]}")"
  fi
  echo
}

# source: https://stackoverflow.com/a/17841619
function join {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

main "$@"
