#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# I can remove this when trashy gets support for macOS, which is blocked by an issue
# with the library they use for accessing the trash:
# https://github.com/Byron/trash-rs/issues/8

function main {
  name="$(basename "$0")"

  if (($# == 0)); then
    printf 'usage: %s [FILES...]\n' "$name" 1>&2
    exit 1
  fi

  extant_files=()
  for file in "$@"; do
    # -e considers broken symlinks to be nonexistent, but I don't, since the
    # broken symlink file _does_ exist, even if its target doesn't. -L will
    # return true for any symlinks, including broken ones, so I include
    # that check.
    if [[ ! -e "$file" && ! -L "$file" ]]; then
      printf '%s: "%s" does not exist\n' "$name" "$file"
      continue
    fi

    file="$(realpath --no-symlinks "$file")"
    # This replaces \ with \\
    file="${file//\\/\\\\}"
    # This replaces " with \"
    file="${file//\"/\\\"}"
    file="the POSIX file \"$file\""

    extant_files=("${extant_files[@]}" "$file")
  done

  if ((${#extant_files[@]} > 0)); then
    extant_files_joined_by_comma="$(join ', ' "${extant_files[@]}")"
    chronic osascript -e \
      "tell app \"Finder\" to move {$extant_files_joined_by_comma} to trash"
  fi

  # Return success if all files existed
  ((${#extant_files[@]} == $#))
}

# source: https://stackoverflow.com/a/17841619
function join {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

main "$@"
