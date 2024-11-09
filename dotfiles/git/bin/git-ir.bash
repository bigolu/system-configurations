#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

if (($# == 0)); then
  choice="$(git log --oneline | fzf-zoom --prompt 'Choose a commit to rebase from: ' --preview 'git show --patch {1} | delta')"
  hash="$(cut -d ' ' -f 1 <<<"$choice")"
  git rebase --interactive "$hash^"
elif ((${#1} <= 2)); then
  git rebase --interactive "HEAD~$1"
else
  git rebase --interactive "$1^"
fi
