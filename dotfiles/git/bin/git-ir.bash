#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

start_commit=''
if (($# == 0)); then
  # Rebase all the commits I haven't pushed yet
  start_commit="$(git merge-base '@{push}' HEAD)"
elif ((${#1} <= 2)); then
  # The argument is probably a number specifying how many commits from HEAD I want to
  # rebase.
  start_commit="HEAD~$1"
else
  # The argument is a commit-ish specifying the first commit to be included in the
  # rebase.
  start_commit="$1^"
fi

# Save a reference to the commit we were on before the rebase started, in case we
# want to go back. To restore from this point use: git reset --hard refs/bigolu/ir-backup
git update-ref refs/bigolu/ir-backup HEAD

git rebase --interactive --exec 'git check-commit' "$start_commit"
