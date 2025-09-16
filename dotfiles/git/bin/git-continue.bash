#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

git_dir=$(git rev-parse --git-dir)
subcommand=''
if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
  subcommand='rebase'
elif [[ -d "$git_dir/MERGE_HEAD" ]]; then
  subcommand='merge'
elif [[ -d "$git_dir/CHERRY_PICK_HEAD" ]]; then
  subcommand='cherry-pick'
elif [[ -d "$git_dir/REVERT_HEAD" ]]; then
  subcommand='revert'
fi

if [[ -n $subcommand ]]; then
  git "$subcommand" --continue
else
  echo 'Nothing to continue'
fi
