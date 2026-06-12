#nix --interpreter bash
#nix --packages bash
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the current commit (HEAD)."
#USAGE
#USAGE flag "--all-files" help="Check all files" long_help="For faster development, we decide whether to run a job, and which files it runs on, based on the files changed by the commit being checked. However, this logic isn't perfect so you can use this flag to consider all files changed."
#USAGE
#USAGE flag "--job <job>" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `lefthook.yaml` under the `check` hook."
#USAGE complete "job" run=#" fish -c 'complete --do-complete "lefthook run check --job "' "#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

lefthook run check "$@"
