#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter
#MISE description="Sync your environment with the code"
#USAGE long_about """
#USAGE   Run jobs to sync your environment with the code. For example, \
#USAGE   running database migrations whenever the schema changes. You shouldn't have \
#USAGE   to run this manually since git hooks are provided to automatically run this \
#USAGE   after rebases, merges, and checkouts. The list of jobs is in `lefthook.yaml`.
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

lefthook run sync --jobs "${usage_jobs:+${usage_jobs// /,}}"
