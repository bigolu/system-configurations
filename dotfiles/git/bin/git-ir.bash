#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# To set the check command run: git config bigolu.check-command 'the command'
check_command="$(
  # If a config option isn't set, git exits with a non-zero code so the `||`
  # both stops the statement from failing and provides a default value.
  git config --get 'bigolu.check-command' ||
    echo 'false'
)"

start_commit=''
if (($# == 0)); then
  current_branch="$(git symbolic-ref -q HEAD)"
  tracking_branch="$(git for-each-ref --format='%(upstream:short)' "$current_branch")"
  if [[ -z $tracking_branch ]]; then
    echo 'Error: No tracking branch' >&2
    exit 1
  fi
  start_commit="$(git merge-base "$tracking_branch" HEAD)"
elif ((${#1} <= 2)); then
  start_commit="HEAD~$1"
else
  start_commit="$1^"
fi

git rebase --interactive --exec "$check_command" "$start_commit"
