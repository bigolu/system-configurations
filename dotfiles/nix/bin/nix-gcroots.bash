#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Need sudo since nix won't show a user the PID of processes it doesn't own
run_as_admin="$(which run-as-admin)"
nix_store="$(which nix-store)"
gc_roots_output="$(sudo -- "$run_as_admin" sudo "$nix_store" --gc --print-roots)"
readarray -t roots <<<"$gc_roots_output"

if [[ -n ${NIX_GCROOTS_INCLUDE_SIZE:-} ]]; then
  roots_with_size=()

  for index in "${!roots[@]}"; do
    root="${roots[$index]}"

    # The root is a process. Ignore these since there's usually a ton of them.
    if [[ $root =~ ^{ ]]; then
      continue
    fi

    root_path="$(awk '{print $3}' <<<"$root")"
    unformatted_size="$(nix path-info --closure-size "$root_path" | awk '{ print $2 }')"
    size="$(
      numfmt --to=iec-i --suffix=B --format="%.2f" -- "$unformatted_size"
    )"

    roots_with_size+=("$size $root")
  done

  # sort by size, descending
  printf '%s\n' "${roots_with_size[@]}" | sort --human-numeric-sort --reverse
else
  # sort alphabetically, ascending
  printf '%s\n' "${roots[@]}" | sort
fi
