#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# Need sudo since nix won't show a user the PID of processes it doesn't own
readarray -t roots \
  < <(sudo -- "$(which run-as-admin)" sudo nix-store --gc --print-roots)

if [[ -n "${NIX_GCROOTS_INCLUDE_SIZE:-}" ]]; then
  roots_with_size=()

  for index in "${!roots[@]}"; do
    root="${roots[$index]}"

    # The root is a process. Ignore these since there's usually a ton of them.
    if [[ "$root" =~ ^{ ]]; then
      continue
    fi

    size="$(
      numfmt --to=iec-i --suffix=B --format="%.2f" -- \
        "$(nix path-info --closure-size "$(awk '{print $3}' <<<"$root")" | awk '{ print $2 }')"
    )"

    roots_with_size+=("$size $root")
  done

  # sort by size, descending
  printf '%s\n' "${roots_with_size[@]}" | sort --human-numeric-sort --reverse
else
  # sort alphabetically, ascending
  printf '%s\n' "${roots[@]}" | sort
fi
