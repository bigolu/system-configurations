#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter coreutils moreutils]"
#MISE description="Run quality assurance jobs to find/fix issues"
#USAGE long_about """
#USAGE   Run jobs to find/fix issues with the code. It runs \
#USAGE   on all files that differ between the current branch and the default branch, \
#USAGE   and untracked files. This is usually what you want since you can assume any \
#USAGE   files merged into the default branch have no issues. You usually don't have \
#USAGE   to run this manually since it runs during the git pre-commit hook, where it \
#USAGE   only runs on staged files. The exception to this is when you make changes to how \
#USAGE   any of the jobs work, like modifying `lefthook.yaml` for example. In which \
#USAGE   case, you should run this with the `--all-files` flag which forces the jobs to \
#USAGE   run on all files, even unchanged ones. The list of jobs is in `lefthook.yaml`.
#USAGE """
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#"""
#USAGE   fish -c 'complete --do-complete "lefthook run qa --jobs "'
#USAGE """#
#USAGE
#USAGE flag "-a --all-files" help="Run on all files"

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
  if [[ ${usage_all_files:-} == 'true' ]]; then
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
  #
  # TODO: See if lefthook can support this
  head -c -1 |
  # TODO: lefthook shouldn't run any tasks if `--files-from-stdin` is used and
  # nothing is passed through stdin. Instead, it tries to run tasks and stalls. For
  # now, I use `ifne` to do that.
  ifne lefthook run qa --files-from-stdin "${job_flag[@]}"
