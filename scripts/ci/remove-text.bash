#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.openssl local#nixpkgs.perl local#nixpkgs.gnugrep --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

function main {
  output_variable_name='new-text'

  # Source: https://stackoverflow.com/a/54059744
  #
  # Since we're using command substitution, trailing newlines will be
  # removed. This means any trailing newlines in the original text will not be
  # preserved.
  new_text="$(perl -s -pe's{\Q$text_to_remove}{}' -- -text_to_remove="$TEXT_TO_REMOVE" <(echo "$TEXT"))"

  if (("$(wc -l <<<"$new_text")" > 1)); then
    # This post says the recommended way to get a unique delimiter for multiline
    # strings is to use openssl, though I couldn't find this in the docs:
    # https://github.com/orgs/community/discussions/26288#discussioncomment-3876281
    delimiter="$(openssl rand -hex 8)"
    if contains "$new_text" "$delimiter"; then
      echo "The result text '$new_text' contains the randomly generated string '$delimiter'" 1>&2
      exit 1
    fi

    printf '%s<<%s\n%s\n%s\n' "$output_variable_name" "$delimiter" "$new_text" "$delimiter" >>"${GITHUB_OUTPUT:-/dev/stderr}"
  else
    printf '%s=%s\n' "$output_variable_name" "$new_text" >>"${GITHUB_OUTPUT:-/dev/stderr}"
  fi
}

function contains {
  local text_to_search="$1"
  local target="$2"
  grep "$target" --silent <<<"$text_to_search"
}

main
