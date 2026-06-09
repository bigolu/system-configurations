#nix --interpreter bash
#nix --packages bash
#MISE description="Sync your environment with the code"
#USAGE long_about "Run jobs to sync your environment with the code. For example, running database migrations whenever the schema changes."
#USAGE
#USAGE flag "--job <job>" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `lefthook.yaml` under the `sync` hook."
#USAGE complete "jobs" run=#" fish -c 'complete --do-complete "lefthook run sync --job "' "#
#USAGE
#USAGE flag "--ask" help="Show diff and confirm before syncing" long_help="Show a diff of the current state and the new state, and ask for confirmation, before syncing. This is only supported by the `system` job."

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

command=(lefthook run sync)
for arg in "$@"; do
	if [[ $arg != '--ask' ]]; then
		command+=("$arg")
	fi
done
"${command[@]}"
