#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# The pre-commit hook is not run when you do `git rebase --continue`. This adds
# an exec line after each commit to run the pre-commit hook.
pre_commit_hook="$(git rev-parse --absolute-git-dir)/hooks/pre-commit"
run_pre_commit_flags=()
if type -P lefthook >/dev/null && [[ -e $pre_commit_hook ]]; then
  run_pre_commit_flags=(
    --exec
    # `head` removes the final character, which is the null byte '\0'. This is
    # necessary because lefthook expects the file names to be separated by a
    # '\0' so a trailing one would result in an empty string being passed in as
    # a file name.
    #
    # TODO: See if lefthook can support this
    'git diff -z --diff-filter=d --name-only HEAD~1 HEAD | head -c -1 | lefthook run pre-commit --files-from-stdin'
  )
fi

start_commit=''
if (($# == 0)); then
  merge_base="$(git merge-base origin/HEAD HEAD)"
  choice="$(
    git log "${merge_base}..HEAD" --oneline |
      fzf \
        --no-sort \
        --prompt 'Choose a commit to rebase from: ' \
        --preview 'git show --patch {1} | delta' \
        --preview-window '60%'
  )"
  hash="$(cut -d ' ' -f 1 <<<"$choice")"
  start_commit="$hash^"
elif ((${#1} <= 2)); then
  start_commit="HEAD~$1"
else
  start_commit="$1^"
fi

git rebase --interactive "${run_pre_commit_flags[@]}" "$start_commit"
