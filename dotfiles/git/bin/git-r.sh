#!/usr/bin/env sh

set -o errexit
set -o nounset

if [ $# -eq 0 ]; then
  echo "ERROR: You must provide the number of commits to rebase" >&2
  exit 1
fi

git rebase -i "HEAD~$1"
