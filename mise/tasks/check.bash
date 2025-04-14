#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils]"
#MISE description="Report/Fix issues"
#USAGE long_about """
#USAGE   Run checks on the code, automatically fixing issues if possible. It runs \
#USAGE   on all files that differ between the current branch and the default branch, \
#USAGE   and untracked files. This is usually what you want since you can assume any \
#USAGE   files merged into the default branch have been checked. You usually don't have \
#USAGE   to run this manually since it runs during the git pre-commit hook, where it \
#USAGE   only runs on staged files. The exception to this is when you make changes to how \
#USAGE   any of the checks work, like modifying `lefthook.yaml` for example. In which \
#USAGE   case, you should run this with the `--all` flag which forces the checks to \
#USAGE   run on all files, even unchanged ones. The list of checks is in `lefthook.yaml`.
#USAGE """
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#"""
#USAGE   yq \
#USAGE     '
#USAGE       [
#USAGE         # Get all job maps within the check map. Jobs are any maps with a "name" key.
#USAGE         .check.jobs | .. | select(has("name")) |
#USAGE
#USAGE         # Exclude jobs that have child jobs, we only want the individual jobs
#USAGE         select(has("group") | not) |
#USAGE
#USAGE         .name
#USAGE       ] |
#USAGE       sort |
#USAGE       unique |
#USAGE       .[]
#USAGE     ' \
#USAGE     lefthook.yaml
#USAGE """#
#USAGE
#USAGE flag "-a --all" help="Run on all files"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

eval "jobs=(${usage_jobs:-})"

job_flag=()
# shellcheck disable=2154
# `jobs` is defined in an `eval` statement above
if ((${#jobs[@]} > 0)); then
  joined_jobs="$(printf '%s,' "${jobs[@]}")"
  joined_jobs="${joined_jobs::-1}"

  job_flag=(--jobs "$joined_jobs")
fi

{
  if [[ ${usage_all:-} == 'true' ]]; then
    # Print all tracked files
    git ls-files -z
  else
    # Print the files that differ between the current branch and the default branch.
    # Use the merge base in case the current branch is behind the default branch.
    merge_base="$(git merge-base origin/HEAD HEAD)"
    git diff -z --diff-filter=d --name-only "$merge_base"
  fi

  # Print untracked files
  git ls-files -z --others --exclude-standard
} |
  # This removes the final character, which is the null byte '\0'. This is
  # necessary because lefthook expects the file names to be separated by a
  # '\0' so a trailing one would result in an empty string being passed in as
  # a file name.
  head -c -1 |
  lefthook run check --files-from-stdin "${job_flag[@]}"
