#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gitMinimal local#nixpkgs.lefthook --command bash

# shellcheck shell=bash

set -o errexit
shopt -s inherit_errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  groups="$1"
  files="$2"

  lefthook_command=(lefthook run check)
  if [[ "$groups" != 'all' ]]; then
    lefthook_command+=(--commands "$groups")
  fi

  if [[ "$files" = 'all' ]]; then
    "${lefthook_command[@]}" --all-files
  elif [[ "$files" = 'diff-from-default' ]]; then
    get_files_that_differ_from_default_branch \
      | "${lefthook_command[@]}" --files-from-stdin
  else
    echo "Error: invalid file set '$files'" >&2
    exit 1
  fi
}

function get_files_that_differ_from_default_branch {
  # I'm using merge-base in case the current branch is behind the default branch.
  git diff -z --diff-filter=d --name-only \
    "$(git merge-base "${GIT_REMOTE:-origin}/${GIT_REF:-HEAD}" HEAD)"
  # Untracked files
  git ls-files -z --others --exclude-standard
}

main "$@"
