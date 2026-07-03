#nix --interpreter bash --packages bash
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the current commit (HEAD)."
#USAGE
#USAGE arg "[job]" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `lefthook.yaml` under the `check` hook."
#USAGE complete "job" run=#" fish -c 'complete --do-complete "lefthook run check --job "' "#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

command=(lefthook run check)
for arg in "$@"; do
	command+=(--job "$arg")
done
"${command[@]}"
