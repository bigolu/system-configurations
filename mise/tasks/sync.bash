#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter]"
#MISE description="Synchronize your environment with the code"
#USAGE long_about """
#USAGE   Run jobs to synchronize your environment with the code. For example, \
#USAGE   running database migrations whenever the schema changes. You shouldn't have \
#USAGE   to run this manually since a git hook is provided to automatically run this \
#USAGE   after `git pull` and `git checkout`. The list of jobs is in `lefthook.yaml`.
#USAGE """
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#"""
#USAGE   fish -c 'complete --do-complete "lefthook run sync --jobs "'
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

lefthook_job_args=()
eval "jobs=(${usage_jobs:-})"
# shellcheck disable=2154
# `jobs` is defined in an `eval` statement above
if ((${#jobs[@]} > 0)); then
  joined_jobs="$(printf '%s,' "${jobs[@]}")"
  joined_jobs="${joined_jobs::-1}"

  lefthook_job_args+=(--jobs "$joined_jobs")
fi

# lefthook doesn't run any jobs if no files are passed in so we use `--force` to make
# them run.
lefthook run sync --force "${lefthook_job_args[@]}"
