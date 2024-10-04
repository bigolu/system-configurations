#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if (($# == 0)); then
  echo "ERROR: You must provide the number of commits to rebase" >&2
  exit 1
fi

git rebase -i "HEAD~$1"
