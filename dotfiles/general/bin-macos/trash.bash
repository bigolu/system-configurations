#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# I can remove this when trashy gets support for macOS, which is blocked by an issue with the library they use
# for accessing the trash: https://github.com/Byron/trash-rs/issues/8

function main {
  name="$(basename "$0")"
  if (($# > 0)); then
    extant_files=()
    for file in "$@"; do
      # -h accounts for broken symlinks
      if [[ -e "$file" || -L "$file" ]]; then
        file="$(realpath --no-symlinks "$file")"
        # This replaces '\' with '\\'
        file="${file//\\/\\\\}"
        # This replaces '"' with '\"'
        file="${file//\"/\\\"}"
        extant_files=("${extant_files[@]}" "the POSIX file \"$file\"")
      else
        printf '%s: "%s" does not exist\n' "$name" "$file"
      fi
    done

    if ((${#extant_files[@]} > 0)); then
      chronic osascript -e "tell app \"Finder\" to move {$(join ', ' "${extant_files[@]}")} to trash"
    fi

    ((${#extant_files[@]} == $#))
  else
    printf 'usage: %s [FILES...]\n' "$name" 1>&2
    exit 64
  fi
}

# source: https://stackoverflow.com/a/17841619
function join {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

main "$@"
