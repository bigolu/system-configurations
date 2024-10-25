#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if (($# == 0)); then
  echo 'Error: you must provide the number of commits to rebase or the commit to rebase from' >&2
  exit 1
fi

if ((${#1} <= 2)); then
  git rebase --interactive "HEAD~$1"
else
  git rebase --interactive "$1^"
fi
