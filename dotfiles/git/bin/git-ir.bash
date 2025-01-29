#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if (($# == 0)); then
  choice="$(
    git log "$(git merge-base origin/HEAD HEAD)"..HEAD --oneline \
      | fzf-zoom \
        --no-sort \
        --prompt 'Choose a commit to rebase from: ' \
        --preview 'git show --patch {1} | delta' \
        --preview-window '60%'
  )"
  hash="$(cut -d ' ' -f 1 <<<"$choice")"
  git rebase --interactive "$hash^"
elif ((${#1} <= 2)); then
  git rebase --interactive "HEAD~$1"
else
  git rebase --interactive "$1^"
fi
