#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter]"
#MISE description="Run jobs to find/fix issues"
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
#USAGE   fish -c 'complete --do-complete "lefthook run check --jobs "'
#USAGE """#
#USAGE
#USAGE flag "-a --all-files" help="Run on all files"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

job_flag=()
eval "jobs=(${usage_jobs:-})"
# shellcheck disable=2154
# `jobs` is defined in an `eval` statement above
if ((${#jobs[@]} > 0)); then
  IFS=',' joined_jobs="${jobs[*]}"
  job_flag=(--jobs "$joined_jobs")
fi

LEFTHOOK_CHECK_ALL_FILES="${usage_all_files:-}" lefthook run check "${job_flag[@]}"
