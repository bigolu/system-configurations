#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter]"
#MISE description="Synchronize your environment with the code"
#USAGE long_about """
#USAGE   Run jobs to synchronize your environment with the code. For example, \
#USAGE   running database migrations whenever the schema changes. Run this anytime \
#USAGE   you incorporate someone else's changes. Such as running `git pull` \
#USAGE   or checking out another branch. The jobs to run will be automatically \
#USAGE   determined based on what files changed since the last pull, checkout, etc. \
#USAGE   The list of jobs is in `lefthook.yaml`.
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

eval "jobs=(${usage_jobs:-})"

# lefthook doesn't run any jobs if no files are passed in so we use force to make
# them run.
lefthook_job_args=(--force)
# shellcheck disable=2154
# `jobs` is defined in an `eval` statement above
if ((${#jobs[@]} > 0)); then
  joined_jobs="$(printf '%s,' "${jobs[@]}")"
  joined_jobs="${joined_jobs::-1}"

  lefthook_job_args+=(--jobs "$joined_jobs")
fi

# TODO: For any job that has 'follows' enabled, 'execution_out' needs to be enabled
# or else nothing will show. I have it off by default so this will enable it. I
# should open an issue for allowing output to be configured per job, the same way
# 'follows' is.
#
# TODO: According to the lefthook documentation, this variable should _extend_ the
# output values specified in the config file, but it seems to be overwriting them
# instead. For now, I'm duplicating the values specified in my config here. I should
# open an issue.
LEFTHOOK_OUTPUT='execution_info,execution_out' lefthook run sync "${lefthook_job_args[@]}"
